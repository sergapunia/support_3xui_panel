import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LinksDialog extends StatelessWidget {
  final String email;
  final List<String> links;
  final String? subscriptionUrl; // rendered first if provided

  const LinksDialog({
    super.key,
    required this.email,
    required this.links,
    this.subscriptionUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasSub = subscriptionUrl != null && subscriptionUrl!.isNotEmpty;
    final int totalItems = (hasSub ? 1 : 0) + links.length;

    return AlertDialog(
      title: Text('Links for $email'),
      content: SizedBox(
        width: double.maxFinite,
        child: totalItems == 0
            ? const Center(child: Text('No links found'))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: totalItems,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, index) {
                  if (hasSub && index == 0) {
                    return _SubscriptionCard(url: subscriptionUrl!);
                  }
                  final linkIndex = hasSub ? index - 1 : index;
                  return _LinkCard(link: links[linkIndex]);
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String url;
  const _SubscriptionCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.subscriptions_outlined, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text(
                'SUBSCRIPTION LINK',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(data: url, version: QrVersions.auto, size: 200.0),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subscription URL copied')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String link;
  const _LinkCard({required this.link});

  String _alias() {
    if (link.contains('#')) return Uri.decodeComponent(link.split('#').last);
    return 'Link';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: QrImageView(data: link, version: QrVersions.auto, size: 200.0),
          ),
        ),
        const SizedBox(height: 8),
        Text(_alias(), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                link,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
