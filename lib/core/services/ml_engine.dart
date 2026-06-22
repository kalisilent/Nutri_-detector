import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// Pure-Dart LightGBM multiclass inference.
/// Loads the compact tree JSON exported from Python.
class MlEngine {
  late final List<String> classes;
  late final int numClass;
  late final int numIterations;
  late final List<String> featureNames;
  late final List<_Tree> _trees;

  bool _loaded = false;

  static final MlEngine instance = MlEngine._();
  MlEngine._();

  Future<void> load() async {
    if (_loaded) return;
    final raw =
        await rootBundle.loadString('assets/ml/model_compact.json');
    final data = json.decode(raw) as Map<String, dynamic>;

    classes = List<String>.from(data['classes']);
    numClass = data['num_class'] as int;
    numIterations = data['num_iterations'] as int;
    featureNames = List<String>.from(data['feature_names']);

    final treesJson = data['trees'] as List;
    _trees = treesJson.map((t) => _Tree.fromJson(t)).toList();

    _loaded = true;
  }

  /// Predict grade and probabilities from nutrient values.
  Map<String, dynamic> predict(Map<String, double> nutrients,
      {int additivesCount = 0}) {
    final input = <double>[];
    for (final name in featureNames) {
      if (name == 'additives_n') {
        input.add(additivesCount.toDouble());
      } else {
        input.add(nutrients[name] ?? -1.0);
      }
    }

    // Sum leaf values per class across all iterations
    final rawScores = List.filled(numClass, 0.0);
    for (var i = 0; i < _trees.length; i++) {
      final classIdx = i % numClass;
      rawScores[classIdx] += _trees[i].evaluate(input);
    }

    // Softmax
    final maxScore = rawScores.reduce(max);
    final exps = rawScores.map((s) => exp(s - maxScore)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    final probs = exps.map((e) => e / sumExp).toList();

    // Find best
    var bestIdx = 0;
    for (var i = 1; i < numClass; i++) {
      if (probs[i] > probs[bestIdx]) bestIdx = i;
    }

    final gradeLabels = {
      'a': 'HEALTHY',
      'b': 'GOOD',
      'c': 'MODERATE',
      'd': 'POOR',
      'e': 'UNHEALTHY',
    };

    final grade = classes[bestIdx];
    final probMap = <String, double>{};
    for (var i = 0; i < numClass; i++) {
      probMap[classes[i]] = double.parse(probs[i].toStringAsFixed(4));
    }

    return {
      'grade': grade,
      'grade_label': gradeLabels[grade] ?? 'UNKNOWN',
      'grade_confidence': probMap[grade] ?? 0.0,
      'grade_probabilities': probMap,
    };
  }
}

class _Tree {
  final List<int> features;
  final List<double> thresholds;
  final List<int> lefts;
  final List<int> rights;

  _Tree(this.features, this.thresholds, this.lefts, this.rights);

  factory _Tree.fromJson(Map<String, dynamic> j) {
    return _Tree(
      List<int>.from(j['features']),
      List<double>.from(
          (j['thresholds'] as List).map((e) => (e as num).toDouble())),
      List<int>.from(j['lefts']),
      List<int>.from(j['rights']),
    );
  }

  double evaluate(List<double> input) {
    var idx = 0;
    while (features[idx] != -1) {
      final feat = features[idx];
      final val = input[feat];
      if (val <= thresholds[idx]) {
        idx = lefts[idx];
      } else {
        idx = rights[idx];
      }
    }
    return thresholds[idx]; // leaf value stored in threshold slot
  }
}
