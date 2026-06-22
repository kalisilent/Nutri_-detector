import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../scan/presentation/scan_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardStatsProvider);
    final total = data['total_scans'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Dashboard')),
      body: total == 0
          ? const Center(
              child: Text('Scan products to see your stats here.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                        child:
                            _StatCard(label: 'Total scans', value: '$total')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _StatCard(
                            label: 'Average grade',
                            value: (data['average_grade'] as String? ?? '–')
                                .toUpperCase(),
                            color: AppTheme
                                .gradeColors[data['average_grade']])),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Grade distribution',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: _buildChart(data),
                ),
                const SizedBox(height: 20),
                if ((data['most_common_additives'] as List?)
                        ?.isNotEmpty ==
                    true) ...[
                  Text('Your most common additives',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...(data['most_common_additives'] as List).map((a) {
                    final item = a as Map;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.science_outlined),
                      title: Text(item['code'] as String),
                      trailing: Text('×${item['count']}'),
                    );
                  }),
                ],
              ],
            ),
    );
  }

  Widget _buildChart(Map<String, dynamic> data) {
    final dist = (data['grade_distribution'] as List?) ?? [];
    return BarChart(BarChartData(
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
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < dist.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: ((dist[i] as Map)['count'] as num).toDouble(),
              width: 28,
              borderRadius: BorderRadius.circular(6),
              color: AppTheme.gradeColors[(dist[i] as Map)['grade']],
            ),
          ]),
      ],
    ));
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
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
