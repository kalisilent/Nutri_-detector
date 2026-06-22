import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../scan/data/scan_repository.dart';

final historyProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(scanRepositoryProvider).history());

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return const Center(
                child: Text('No scans yet.\nScan your first product!',
                    textAlign: TextAlign.center));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(historyProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = Map<String, dynamic>.from(items[i] as Map);
                final grade = (item['grade'] as String?)?.toLowerCase();
                final color = AppTheme.gradeColors[grade] ?? Colors.grey;
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
                    title: Text(
                        '${item['ingredient_count']} ingredients'),
                    subtitle: Text((item['created_at'] as String)
                        .replaceFirst('T', '  ')
                        .substring(0, 17)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref
                            .read(scanRepositoryProvider)
                            .deleteScan(item['scan_id'] as String);
                        ref.invalidate(historyProvider);
                      },
                    ),
                    onTap: () =>
                        context.push('/result/${item['scan_id']}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
