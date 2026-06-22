/// Ported from backend/app/services/ocr/parsers.py

/// Classify OCR text as nutrition / ingredients / both / unknown.
String detectPanelType(String rawText) {
  final text = rawText.toLowerCase();

  const nutritionKw = [
    'nutrition facts', 'calories', 'total fat',
    'serving size', 'daily value', 'amount per serving',
  ];
  const ingredientKw = [
    'ingredients:', 'ingredients :', 'contains:', 'may contain',
  ];

  final nScore = nutritionKw.where((kw) => text.contains(kw)).length;
  final iScore = ingredientKw.where((kw) => text.contains(kw)).length;

  if (nScore >= 2 && iScore >= 1) return 'both';
  if (nScore >= 2) return 'nutrition';
  if (iScore >= 1) return 'ingredients';
  if (','.allMatches(text).length > 3) return 'ingredients';
  return 'unknown';
}

/// Parse ingredient tokens and E-numbers from OCR text.
({List<String> tokens, List<String> eNumbers}) parseIngredients(
    String rawText) {
  var text = rawText.toLowerCase();

  for (final marker in ['ingredients:', 'ingredients :', 'contains:']) {
    final idx = text.indexOf(marker);
    if (idx != -1) {
      text = text.substring(idx + marker.length);
      break;
    }
  }

  // Extract E-numbers
  final eNumbers = RegExp(r'E\d{3}[a-z]?', caseSensitive: false)
      .allMatches(text)
      .map((m) => m.group(0)!.toUpperCase())
      .toList();

  // Strip percentages
  text = text.replaceAll(RegExp(r'\(?\d+\.?\d*\s*%\)?'), '');
  // Strip brackets
  text = text.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '');

  final cleaned = <String>[];
  for (var part in text.split(RegExp(r'[,;.]'))) {
    part = part.replaceAll(RegExp(r'^[\s:*\-_/\\0-9%]+'), '');
    part = part.replaceAll(RegExp(r'[\s:*\-_/\\0-9%]+$'), '');
    part = part.replaceFirst(RegExp(r'^and\s+'), '');
    part = part.trim();
    if (part.length > 2 &&
        part.length <= 50 &&
        !RegExp(r'^\d+$').hasMatch(part.replaceAll(' ', ''))) {
      cleaned.add(part);
    }
  }

  return (tokens: cleaned, eNumbers: eNumbers);
}

/// Extract nutrient values from Nutrition Facts OCR text.
Map<String, double> parseNutrition(String rawText) {
  final text = rawText.toLowerCase();
  final extracted = <String, double>{};

  const patterns = {
    'energy_100g': [r'calories\s*(\d+)', r'energy\s*(\d+)'],
    'fat_100g': [r'total\s*fat\s*(\d+\.?\d*)\s*g'],
    'saturated-fat_100g': [r'saturated\s*fat\s*(\d+\.?\d*)\s*g'],
    'carbohydrates_100g': [
      r'total\s*carbohydr?a?t?e?s?\s*(\d+\.?\d*)',
      r'carbohydr?a?t?e?s?\s*(\d+\.?\d*)',
    ],
    'sugars_100g': [
      r'total\s*sugars?\s*(\d+\.?\d*)',
      r'sugars?\s*(\d+\.?\d*)\s*g',
    ],
    'fiber_100g': [r'(?:dietary\s*)?fiber\s*(\d+\.?\d*)\s*g'],
    'proteins_100g': [r'prote?a?in\s*(\d+\.?\d*)\s*g'],
    'salt_100g': [r'salt\s*(\d+\.?\d*)\s*g'],
    'sodium_100g': [r'sodium\s*(\d+\.?\d*)\s*m?g'],
  };

  for (final entry in patterns.entries) {
    for (final pattern in entry.value) {
      final match = RegExp(pattern).firstMatch(text);
      if (match != null) {
        var val = double.tryParse(match.group(1)!) ?? 0;
        if (entry.key == 'energy_100g' && val < 1000) {
          val *= 4.184; // kcal → kJ
        }
        if (entry.key == 'sodium_100g' && val > 5) {
          val /= 1000; // mg → g
        }
        extracted[entry.key] = val;
        break;
      }
    }
  }

  if (extracted.containsKey('sodium_100g') &&
      !extracted.containsKey('salt_100g')) {
    extracted['salt_100g'] =
        double.parse((extracted['sodium_100g']! * 2.5).toStringAsFixed(3));
  }

  return extracted;
}
