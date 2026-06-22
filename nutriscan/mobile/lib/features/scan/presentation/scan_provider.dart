import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scan_repository.dart';

final scanResultProvider =
    AsyncNotifierProvider<ScanNotifier, Map<String, dynamic>?>(
        ScanNotifier.new);

class ScanNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async => null;

  Future<String?> scan(File image) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(scanRepositoryProvider).scanImage(image));
    return state.valueOrNull?['scan_id'] as String?;
  }

  void reset() => state = const AsyncData(null);
}

final scanDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
    (ref, id) => ref.watch(scanRepositoryProvider).getScan(id));
