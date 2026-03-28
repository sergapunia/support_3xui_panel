import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../riverpod/panel_notifier.dart';
import '../widgets/links_dialog.dart';

class ClientListScreen extends ConsumerWidget {
  final Inbound inbound;
  const ClientListScreen({super.key, required this.inbound});

  void _showEditClientDialog(BuildContext context, WidgetRef ref, int inboundId, Client client) {
    final subNameController = TextEditingController(text: client.subName);
    final limitController = TextEditingController(text: client.limitIp.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${client.email}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subNameController,
              decoration: const InputDecoration(labelText: 'Имя (Subscription Name)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: limitController,
              decoration: const InputDecoration(labelText: 'Device Limit'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final limit = int.tryParse(limitController.text) ?? 0;
              ref.read(panelProvider.notifier).updateClient(inboundId, client.email, {
                'sub_name': subNameController.text,
                'tg_id': subNameController.text,
                'limit_ip': limit,
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddClientDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final subNameController = TextEditingController();
    final limitController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subNameController,
              decoration: const InputDecoration(labelText: 'Subscription Name (Optional)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: limitController,
              decoration: const InputDecoration(labelText: 'Device Limit (0 = Unlimited)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final limit = int.tryParse(limitController.text) ?? 0;
              ref
                  .read(panelProvider.notifier)
                  .addClient(inbound.id, emailController.text, limitIp: limit, subName: subNameController.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showLinks(BuildContext context, WidgetRef ref, Client client) async {
    // Fetch both in parallel — subscription URL by UUID, links by email
    final results = await Future.wait([
      ref.read(panelProvider.notifier).getClientLinks(inbound.id, client.email),
      ref.read(panelProvider.notifier).getSubscriptionLink(client.id),
    ]);
    if (!context.mounted) return;

    final links = results[0] as List<String>;
    final subUrl = results[1] as String?;

    showDialog(
      context: context,
      builder: (context) => LinksDialog(
        email: client.subName.isNotEmpty ? client.subName : client.email,
        links: links,
        subscriptionUrl: subUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panelState = ref.watch(panelProvider);
    final ib = panelState.inbounds.firstWhere((e) => e.id == inbound.id, orElse: () => inbound);

    return Scaffold(
      appBar: AppBar(title: Text(ib.remark.toUpperCase())),
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ib.clients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final client = ib.clients[index];
              final displayName = client.subName.isNotEmpty ? client.subName : client.email;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: client.enable ? Colors.white.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: client.enable ? Colors.white10 : Colors.red.withOpacity(0.2)),
                        ),
                        child: Icon(Icons.person, color: client.enable ? Colors.white : Colors.red[300]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            if (client.subName.isNotEmpty)
                              Text('ID: ${client.email}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                            Text(
                              'DEVICES: ${client.onlineCount} / ${client.limitIp == 0 ? "∞" : client.limitIp}',
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showEditClientDialog(context, ref, ib.id, client),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.qr_code, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showLinks(context, ref, client),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => ref.read(panelProvider.notifier).deleteClient(ib.id, client.email),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (panelState.isActionLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClientDialog(context, ref),
        child: const Icon(Icons.add_reaction_outlined),
      ),
    );
  }
}
