import 'dart:math';

/// Simple fuzzy matching using normalized Levenshtein + containment.
/// Not as sophisticated as rapidfuzz WRatio, but good enough on-device.
class FuzzyMatcher {
  final List<String> vocabulary;
  final int cutoff;

  FuzzyMatcher(this.vocabulary, {this.cutoff = 70});

  /// Find best match for [query] in vocabulary.
  /// Returns null if no match above cutoff.
  ({String match, double score})? bestMatch(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;

    String? bestName;
    double bestScore = 0;

    for (final vocab in vocabulary) {
      final v = vocab.toLowerCase();

      // Exact match
      if (q == v) return (match: vocab, score: 100.0);

      // Calculate combined score
      final score = _combinedScore(q, v);
      if (score > bestScore) {
        bestScore = score;
        bestName = vocab;
      }
    }

    if (bestName != null && bestScore >= cutoff) {
      return (match: bestName, score: bestScore);
    }
    return null;
  }

  double _combinedScore(String a, String b) {
    // Containment check (one contains the other)
    if (a.contains(b) || b.contains(a)) {
      final ratio = min(a.length, b.length) / max(a.length, b.length);
      return 70 + (ratio * 30); // 70-100 range
    }

    // Token overlap for multi-word strings
    final aTokens = a.split(RegExp(r'\s+')).toSet();
    final bTokens = b.split(RegExp(r'\s+')).toSet();
    if (aTokens.length > 1 || bTokens.length > 1) {
      final intersection = aTokens.intersection(bTokens).length;
      final union = aTokens.union(bTokens).length;
      if (union > 0) {
        final jaccard = intersection / union;
        if (jaccard > 0.5) return 60 + (jaccard * 40);
      }
    }

    // Normalized edit distance
    final dist = _editDistance(a, b);
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 0;
    return ((1 - dist / maxLen) * 100).clamp(0, 100);
  }

  int _editDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Optimize: if length difference too large, skip
    if ((a.length - b.length).abs() > max(a.length, b.length) * 0.5) {
      return max(a.length, b.length);
    }

    final prev = List.generate(b.length + 1, (i) => i);
    final curr = List.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce(min);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return curr[b.length];
  }
}
