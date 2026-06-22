import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String rawText;
  final double meanConfidence;
  final String? error;

  OcrResult({required this.rawText, this.meanConfidence = 0, this.error});
}

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> recognize(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);

      if (recognized.text.trim().isEmpty) {
        return OcrResult(
          rawText: '',
          error: 'No text found in image. Try a clearer photo.',
        );
      }

      // Calculate mean confidence from blocks
      var totalConf = 0.0;
      var blockCount = 0;
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          if (line.confidence != null) {
            totalConf += line.confidence!;
            blockCount++;
          }
        }
      }
      final avgConf = blockCount > 0 ? totalConf / blockCount : 0.5;

      return OcrResult(
        rawText: recognized.text,
        meanConfidence: avgConf,
      );
    } catch (e) {
      return OcrResult(
        rawText: '',
        error: 'OCR failed: $e',
      );
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
