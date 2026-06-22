import 'dart:io';
import 'package:uuid/uuid.dart';

import 'fuzzy_matcher.dart';
import 'knowledge_base.dart';
import 'ml_engine.dart';
import 'ocr_service.dart';
import 'parsers.dart';

const _uuid = Uuid();

/// Orchestrates: OCR → parse → match → explain → predict grade.
/// Runs entirely on-device, no network needed.
class ScanPipeline {
  static final ScanPipeline instance = ScanPipeline._();
  ScanPipeline._();

  FuzzyMatcher? _matcher;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await MlEngine.instance.load();
    await KnowledgeBase.instance.load();
    _matcher = FuzzyMatcher(KnowledgeBase.instance.vocabList, cutoff: 70);
    _ready = true;
  }

  Future<Map<String, dynamic>> scan(File imageFile) async {
    if (!_ready) await init();

    // 1. OCR
    final ocr = await OcrService.instance.recognize(imageFile);
    if (ocr.error != null) {
      return {'error': ocr.error, 'scan_id': _uuid.v4()};
    }

    // 2. Panel type detection
    final panelType = detectPanelType(ocr.rawText);

    List<Map<String, dynamic>> matched = [];
    List<String> unmatched = [];
    List<String> eNumbers = [];
    List<Map<String, dynamic>> additives = [];
    Map<String, double> nutrients = {};

    // 3. Ingredients branch
    if (panelType == 'ingredients' || panelType == 'both') {
      final parsed = parseIngredients(ocr.rawText);
      eNumbers = parsed.eNumbers;

      // Fuzzy match tokens to vocabulary
      for (final token in parsed.tokens) {
        final result = _matcher!.bestMatch(token);
        if (result != null) {
          final info =
              KnowledgeBase.instance.getIngredientInfo(result.match);
          matched.add({
            'ocr_text': token,
            'matched_to': result.match,
            'confidence': result.score.round(),
            if (info != null) 'explanation': info['what'],
            if (info != null && info['safety'] != null)
              'safety': info['safety'],
          });
        } else {
          unmatched.add(token);
        }
      }

      // Explain additives
      for (final code in eNumbers) {
        final info = KnowledgeBase.instance.getAdditiveInfo(code);
        if (info != null) {
          additives.add(info);
        } else {
          additives.add({
            'code': code,
            'name': 'Unknown Additive',
            'what': 'This additive code was not found in our database.',
            'safety': 'Check official food safety resources.',
          });
        }
      }
    }

    // 4. Nutrition branch
    if (panelType == 'nutrition' ||
        panelType == 'both' ||
        panelType == 'unknown') {
      nutrients = parseNutrition(ocr.rawText);
    }

    // 5. Grade prediction
    final prediction = MlEngine.instance.predict(
      nutrients,
      additivesCount: eNumbers.length,
    );

    // Low confidence guard
    if (nutrients.length < 3 &&
        (panelType == 'nutrition' || panelType == 'unknown')) {
      prediction['grade_label'] =
          '${prediction['grade_label']} (LOW CONFIDENCE — few nutrients readable)';
    }

    final scanId = _uuid.v4();

    return {
      'scan_id': scanId,
      'panel_type': panelType,
      'raw_ocr': ocr.rawText,
      'ocr_confidence': ocr.meanConfidence,
      'nutrients': nutrients,
      'ingredients': matched,
      'unmatched': unmatched,
      'additives': additives,
      'ingredient_count': matched.length,
      'created_at': DateTime.now().toIso8601String(),
      ...prediction,
    };
  }
}
