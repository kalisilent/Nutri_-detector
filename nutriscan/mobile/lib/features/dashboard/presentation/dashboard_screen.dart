import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

final dashboardProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ref.watch(apiClientProvider).get('/dashboard');
  return resp.data as Map<String, dynamic>;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Health Dashboard')),
      body: dash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final dist = (data['grade_distribution'] as List?) ?? [];
          final total = data['total_scans'] as int? ?? 0;
          final avg = data['average_grade'] as String?;
          final additives =
              (data['most_common_additives'] as List?) ?? [];

          if (total == 0) {
            return const Center(
                child: Text('Scan products to see your stats here.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                      child: _StatCard(
                          label: 'Total scans', value: '$total')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _StatCard(
                          label: 'Average grade',
                          value: avg?.toUpperCase() ?? '–',
                          color: AppTheme.gradeColors[avg])),
                ],
              ),
              const SizedBox(height: 20),
              Text('Grade distribution',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                            'ABCDE'[v.toInt()],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < dist.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: ((dist[i]
                                  as Map)['count'] as num)
                              .toDouble(),
                          width: 28,
                          borderRadius: BorderRadius.circular(6),
                          color: AppTheme.gradeColors[
                              (dist[i] as Map)['grade']],
                        ),
                      ]),
                  ],
                )),
              ),
              const SizedBox(height: 20),
              if (additives.isNotEmpty) ...[
                Text('Your most common additives',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...additives.map((a) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.science_outlined),
                      title: Text((a as Map)['code'] as String),
                      trailing: Text('×${a['count']}'),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                          color: color, fontWeight: FontWeight.bold)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
