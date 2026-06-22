import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../scan/presentation/scan_provider.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull ?? '…';
    final scanCount = ref.watch(scanStorageProvider).count;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.eco,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('NutriScan',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Know what you eat',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  trailing: Text(version),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.scanner),
                  title: const Text('Total scans'),
                  trailing: Text('$scanCount'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.wifi_off),
                  title: Text('Fully offline'),
                  subtitle: Text('All processing happens on your device'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.dark_mode_outlined),
                  title: Text('Theme'),
                  subtitle: Text('Follows system setting'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Clear all scan history',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all history?'),
                    content:
                        const Text('This will delete all your saved scans.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(scanStorageProvider).clearAll();
                  ref.invalidate(historyProvider);
                  ref.invalidate(dashboardStatsProvider);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'NutriScan uses your trained ML model to grade food products. '
            'Educational information based on Nutri-Score and NOVA. '
            'Not medical advice.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
