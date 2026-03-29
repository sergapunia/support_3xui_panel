import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../riverpod/panel_notifier.dart';
import '../../riverpod/auth_notifier.dart';
import 'client_list_screen.dart';
import 'config_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(panelProvider.notifier).fetchInbounds());
  }

  void _showAddInboundDialog() async {
    final panel = ref.read(panelServiceProvider);
    final config = await panel.getConfig();
    if (config == null) return;

    final inbounds = ref.read(panelProvider).inbounds;
    final usedPorts = inbounds.map((e) => e.port).toSet();

    final portCount = config.portRangeEnd - config.portRangeStart + 1;
    final allPorts = List.generate(
      portCount > 0 ? portCount : 0,
      (index) => config.portRangeStart + index,
    );

    final availablePorts = allPorts.where((p) => !usedPorts.contains(p)).toList();

    String? warning;
    int? selectedPort;

    if (availablePorts.isEmpty) {
      warning = 'No free ports available in range ${config.portRangeStart}-${config.portRangeEnd}!';
    } else {
      availablePorts.shuffle();
      selectedPort = availablePorts.first;
    }

    final suffixController = TextEditingController();
    final portController = TextEditingController(text: selectedPort?.toString() ?? '');
    final targetController = TextEditingController(text: config.defaultTarget);
    final sniController = TextEditingController(text: config.defaultSni);
    final ipCascadController = TextEditingController();
    final portCascadController = TextEditingController();

    bool isAnyvaiCascad = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Inbound'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (warning != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(warning, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                      ],
                    ),
                  ),
                TextField(controller: suffixController, decoration: const InputDecoration(labelText: 'Remark Suffix')),
                const SizedBox(height: 16),
                TextField(controller: portController, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextField(controller: targetController, decoration: const InputDecoration(labelText: 'Target (e.g. google.com:443)')),
                const SizedBox(height: 16),
                TextField(controller: sniController, decoration: const InputDecoration(labelText: 'SNI')),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Standard'),
                      selected: !isAnyvaiCascad,
                      onSelected: (val) => setDialogState(() => isAnyvaiCascad = !val),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Anyvai Cascad'),
                      selected: isAnyvaiCascad,
                      onSelected: (val) => setDialogState(() => isAnyvaiCascad = val),
                    ),
                  ],
                ),
                if (isAnyvaiCascad) ...[
                  const SizedBox(height: 16),
                  TextField(controller: ipCascadController, decoration: const InputDecoration(labelText: 'Cascade IP (Override)')),
                  const SizedBox(height: 16),
                  TextField(controller: portCascadController, decoration: const InputDecoration(labelText: 'Cascade Port (Override)'), keyboardType: TextInputType.number),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: warning != null
                  ? null
                  : () {
                      final port = int.tryParse(portController.text);
                      if (port == null) return;

                      final cascadPort = int.tryParse(portCascadController.text);

                      ref.read(panelProvider.notifier).addInbound(
                            suffixController.text,
                            port,
                            targetController.text,
                            sniController.text,
                            ipCascad: isAnyvaiCascad ? ipCascadController.text : null,
                            portCascad: isAnyvaiCascad ? cascadPort : null,
                          );
                      Navigator.pop(context);
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteInbound(BuildContext context, dynamic ib) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Inbound?'),
        content: Text('Are you sure you want to delete ${ib.remark}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(panelProvider.notifier).deleteInbound(ib.id);
              Navigator.pop(c);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelState = ref.watch(panelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbounds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ConfigScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Stack(
        children: [
          panelState.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.black,
                  onRefresh: () => ref.read(panelProvider.notifier).fetchInbounds(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: panelState.inbounds.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ib = panelState.inbounds[index];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => ClientListScreen(inbound: ib)),
                          ),
                          onLongPress: () => _confirmDeleteInbound(context, ib),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Icon(
                                    ib.protocol == 'vless' ? Icons.security : Icons.storage,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ib.remark.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'PORT: ${ib.port} | PROTO: ${ib.protocol.toUpperCase()}',
                                        style: TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${ib.clients.length} USERS',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTraffic(ib.up + ib.down),
                                      style: TextStyle(color: Colors.white38, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                      onPressed: () => _confirmDeleteInbound(context, ib),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          if (panelState.isActionLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInboundDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTraffic(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
