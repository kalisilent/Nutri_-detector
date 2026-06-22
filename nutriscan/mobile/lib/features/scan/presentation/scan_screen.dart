import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'scan_provider.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref,
      ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 92);
    if (picked == null) return;

    final scanId =
        await ref.read(scanResultProvider.notifier).scan(File(picked.path));

    if (!context.mounted) return;
    final state = ref.read(scanResultProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error.toString())));
    } else if (scanId != null) {
      context.push('/result/$scanId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanning = ref.watch(scanResultProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('NutriScan')),
      body: Center(
        child: scanning
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Reading the label…\nThis takes a few seconds.',
                      textAlign: TextAlign.center),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.document_scanner_outlined,
                        size: 96, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('Scan a food packet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Photograph the ingredient list or the Nutrition '
                      'Facts panel. We read it, explain every ingredient, '
                      'and grade the product A to E.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 40),
                    FilledButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      onPressed: () =>
                          _pick(context, ref, ImageSource.camera),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () =>
                          _pick(context, ref, ImageSource.gallery),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
