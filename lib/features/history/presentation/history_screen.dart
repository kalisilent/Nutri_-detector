import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../scan/presentation/scan_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: items.isEmpty
          ? const Center(
              child: Text('No scans yet.\nScan your first product!',
                  textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final grade = (item['grade'] as String?)?.toLowerCase();
                final color = AppTheme.gradeColors[grade] ?? Colors.grey;
                final count = item['ingredient_count'] as int? ?? 0;
                final date = (item['created_at'] as String?)
                        ?.replaceFirst('T', '  ')
                        .substring(0, 17) ??
                    '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      child: Text(grade?.toUpperCase() ?? '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text('$count ingredients'),
                    subtitle: Text(date),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final id = item['scan_id'] as String;
                        ref.read(scanStorageProvider).deleteScan(id);
                        ref.invalidate(historyProvider);
                        ref.invalidate(dashboardStatsProvider);
                      },
                    ),
                    onTap: () =>
                        context.push('/result/${item['scan_id']}'),
                  ),
                );
              },
            ),
    );
  }
}
