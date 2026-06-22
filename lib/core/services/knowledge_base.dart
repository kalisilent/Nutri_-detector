import 'dart:convert';
import 'package:flutter/services.dart';

/// Loads bundled knowledge for ingredient and additive explanations.
class KnowledgeBase {
  static final KnowledgeBase instance = KnowledgeBase._();
  KnowledgeBase._();

  Map<String, dynamic> _additives = {};
  Map<String, dynamic> _ingredients = {};
  Map<String, dynamic> _additivesKb = {};
  List<String> _vocabList = [];
  bool _loaded = false;

  List<String> get vocabList => _vocabList;

  Future<void> load() async {
    if (_loaded) return;

    final additivesRaw =
        await rootBundle.loadString('assets/ml/curated_additives.json');
    _additives = json.decode(additivesRaw);

    final ingredientsRaw =
        await rootBundle.loadString('assets/ml/ingredient_explanations.json');
    _ingredients = json.decode(ingredientsRaw);

    final vocabRaw =
        await rootBundle.loadString('assets/ml/ingredient_vocab.json');
    final vocabMap = json.decode(vocabRaw) as Map<String, dynamic>;
    _vocabList = vocabMap.keys.toList();

    // Parse additives KB CSV
    final csvRaw = await rootBundle.loadString('assets/ml/additives_kb.csv');
    final lines = csvRaw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].replaceAll('\r', '').split(',');
      if (parts.length >= 3) {
        _additivesKb[parts[0].trim()] = {
          'count': int.tryParse(parts[1].trim()) ?? 0,
          'most_common_grade': parts[2].trim(),
        };
      }
    }

    _loaded = true;
  }

  /// Get curated explanation for an additive (E-number).
  Map<String, dynamic>? getAdditiveInfo(String code) {
    final upper = code.toUpperCase();

    // Check curated dict first
    if (_additives.containsKey(upper)) {
      final entry = Map<String, dynamic>.from(_additives[upper]);
      entry['code'] = upper;
      entry['source'] = 'curated';
      return entry;
    }

    // Fallback to KB frequency data
    if (_additivesKb.containsKey(upper)) {
      final kb = _additivesKb[upper]!;
      return {
        'code': upper,
        'name': 'Additive',
        'what':
            'Found in ${kb['count']} products in our database.',
        'safety':
            "Most commonly appears in grade '${kb['most_common_grade']}' products.",
        'source': 'kb_frequency',
      };
    }

    return null;
  }

  /// Get explanation for an ingredient name.
  Map<String, dynamic>? getIngredientInfo(String name) {
    final lower = name.toLowerCase().trim();
    if (_ingredients.containsKey(lower)) {
      return Map<String, dynamic>.from(_ingredients[lower]);
    }
    return null;
  }
}
