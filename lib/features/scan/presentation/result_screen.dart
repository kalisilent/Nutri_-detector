import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'scan_provider.dart';

class ResultScreen extends ConsumerWidget {
  final String scanId;
  const ResultScreen({super.key, required this.scanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(scanDetailProvider(scanId));

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: data == null
          ? const Center(child: Text('Scan not found'))
          : _ResultBody(data: data),
    );
  }
}

class _ResultBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResultBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final grade = (data['grade'] as String?)?.toLowerCase();
    final ingredients = (data['ingredients'] as List?) ?? [];
    final additives = (data['additives'] as List?) ?? [];
    final nutrients = (data['nutrients'] as Map?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GradeBadge(grade: grade, label: data['grade_label'] as String?),
        const SizedBox(height: 16),
        if (nutrients.isNotEmpty) ...[
          _SectionTitle('Nutrition (per 100g)'),
          _NutrientsCard(nutrients: Map<String, dynamic>.from(nutrients)),
          const SizedBox(height: 16),
        ],
        if (ingredients.isNotEmpty) ...[
          _SectionTitle('Ingredients (${ingredients.length})'),
          ...ingredients.map((i) =>
              _IngredientCard(item: Map<String, dynamic>.from(i as Map))),
          const SizedBox(height: 16),
        ],
        if (additives.isNotEmpty) ...[
          _SectionTitle('Additives explained (${additives.length})'),
          ...additives.map((a) =>
              _AdditiveCard(item: Map<String, dynamic>.from(a as Map))),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Processed entirely on your device. Educational information '
              'based on Nutri-Score. Not medical advice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final String? grade;
  final String? label;
  const _GradeBadge({this.grade, this.label});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.gradeColors[grade] ?? Colors.grey;
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color,
              child: Text(
                grade?.toUpperCase() ?? '?',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nutri-Score',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(label ?? 'Unknown',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _NutrientsCard extends StatelessWidget {
  final Map<String, dynamic> nutrients;
  const _NutrientsCard({required this.nutrients});

  static const _labels = {
    'energy_100g': ('Energy', 'kJ'),
    'fat_100g': ('Fat', 'g'),
    'saturated-fat_100g': ('Saturated fat', 'g'),
    'carbohydrates_100g': ('Carbohydrates', 'g'),
    'sugars_100g': ('Sugars', 'g'),
    'fiber_100g': ('Fiber', 'g'),
    'proteins_100g': ('Protein', 'g'),
    'salt_100g': ('Salt', 'g'),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: _labels.entries
              .where((e) => nutrients[e.key] != null)
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.value.$1),
                        Text(
                          '${(nutrients[e.key] as num).toStringAsFixed(1)} '
                          '${e.value.$2}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _IngredientCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final explanation = item['explanation'] as String?;
    final confidence = (item['confidence'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: explanation == null
          ? ListTile(
              title: Text(item['matched_to'] as String? ?? '?'),
              trailing: _ConfidenceChip(confidence: confidence),
            )
          : ExpansionTile(
              title: Text(item['matched_to'] as String? ?? '?'),
              trailing: _ConfidenceChip(confidence: confidence),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(explanation)),
                if ((item['safety'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item['safety'] as String,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic)),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final double confidence;
  const _ConfidenceChip({required this.confidence});
  @override
  Widget build(BuildContext context) => Chip(
        label: Text('${confidence.round()}%'),
        visualDensity: VisualDensity.compact,
      );
}

class _AdditiveCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AdditiveCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(item['code'] as String? ?? '?',
              style: const TextStyle(fontSize: 10)),
        ),
        title: Text(item['name'] as String? ?? 'Additive'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text(item['what'] as String? ?? '')),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(item['safety'] as String? ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}
