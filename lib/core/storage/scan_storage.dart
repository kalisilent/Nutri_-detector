import 'package:hive_flutter/hive_flutter.dart';

/// Local-only storage for scan history.
class ScanStorage {
  static const _boxName = 'scan_cache';

  Box get _box => Hive.box(_boxName);

  Future<void> saveScan(Map<String, dynamic> result) async {
    final id = result['scan_id'] as String;
    await _box.put(id, result);
  }

  Map<String, dynamic>? getScan(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  List<Map<String, dynamic>> getAllScans() {
    final scans = <Map<String, dynamic>>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is Map) {
        scans.add(Map<String, dynamic>.from(raw));
      }
    }
    // Sort by date descending
    scans.sort((a, b) {
      final aDate = a['created_at'] as String? ?? '';
      final bDate = b['created_at'] as String? ?? '';
      return bDate.compareTo(aDate);
    });
    return scans;
  }

  Future<void> deleteScan(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  int get count => _box.length;

  /// Compute dashboard stats from local data.
  Map<String, dynamic> computeStats() {
    final scans = getAllScans();
    if (scans.isEmpty) {
      return {'total_scans': 0};
    }

    final gradeCounts = <String, int>{};
    final additiveCounts = <String, int>{};

    for (final scan in scans) {
      final grade = (scan['grade'] as String?)?.toLowerCase();
      if (grade != null) {
        gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
      }

      final additives = scan['additives'] as List? ?? [];
      for (final a in additives) {
        if (a is Map) {
          final code = a['code'] as String? ?? '';
          if (code.isNotEmpty) {
            additiveCounts[code] = (additiveCounts[code] ?? 0) + 1;
          }
        }
      }
    }

    // Find average grade
    const gradeOrder = ['a', 'b', 'c', 'd', 'e'];
    var totalScore = 0;
    var gradeCount = 0;
    for (final entry in gradeCounts.entries) {
      final idx = gradeOrder.indexOf(entry.key);
      if (idx >= 0) {
        totalScore += idx * entry.value;
        gradeCount += entry.value;
      }
    }
    final avgIdx =
        gradeCount > 0 ? (totalScore / gradeCount).round().clamp(0, 4) : 2;
    final avgGrade = gradeOrder[avgIdx];

    // Grade distribution
    final distribution = gradeOrder
        .map((g) => {'grade': g, 'count': gradeCounts[g] ?? 0})
        .toList();

    // Top additives
    final sortedAdditives = additiveCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAdditives = sortedAdditives
        .take(5)
        .map((e) => {'code': e.key, 'count': e.value})
        .toList();

    return {
      'total_scans': scans.length,
      'average_grade': avgGrade,
      'grade_distribution': distribution,
      'most_common_additives': topAdditives,
    };
  }
}
