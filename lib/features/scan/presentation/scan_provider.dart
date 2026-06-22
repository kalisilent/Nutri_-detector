import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/scan_pipeline.dart';
import '../../../core/storage/scan_storage.dart';

final scanStorageProvider = Provider((_) => ScanStorage());

final _storageVersion = StateProvider<int>((_) => 0);

final scanResultProvider =
    AsyncNotifierProvider<ScanNotifier, Map<String, dynamic>?>(
        ScanNotifier.new);

class ScanNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async => null;

  Future<String?> scan(File image) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ScanPipeline.instance.scan(image);
      if (result.containsKey('error') && result['grade'] == null) {
        throw Exception(result['error']);
      }
      await ref.read(scanStorageProvider).saveScan(result);
      ref.read(_storageVersion.notifier).state++;
      return result;
    });
    return state.valueOrNull?['scan_id'] as String?;
  }

  void reset() => state = const AsyncData(null);
}

final scanDetailProvider =
    Provider.family<Map<String, dynamic>?, String>((ref, id) {
  ref.watch(_storageVersion);
  return ref.watch(scanStorageProvider).getScan(id);
});

final historyProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(_storageVersion);
  return ref.watch(scanStorageProvider).getAllScans();
});

final dashboardStatsProvider = Provider<Map<String, dynamic>>((ref) {
  ref.watch(_storageVersion);
  return ref.watch(scanStorageProvider).computeStats();
});