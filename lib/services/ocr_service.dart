import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Process an input image (from camera or file) completely offline
  Future<List<String>> extractLicensePlates(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
      final List<String> candidatePlates = [];

      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          final cleaned = cleanPlateText(line.text);
          if (looksLikePlate(cleaned)) {
            candidatePlates.add(cleaned);
          }
        }
      }

      // Sort or remove duplicates
      return candidatePlates.toSet().toList();
    } catch (e) {
      return [];
    }
  }

  /// Cleans and normalizes plate text by stripping out whitespace, punctuation, dashes, and special characters
  static String cleanPlateText(String rawText) {
    return rawText
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase()
        .trim();
  }

  /// Heuristic to determine if a recognized string matches typical vehicle plate shapes (3 to 10 alphanumeric characters)
  static bool looksLikePlate(String cleaned) {
    if (cleaned.length < 3 || cleaned.length > 12) return false;
    final hasLetter = RegExp(r'[A-Z]').hasMatch(cleaned);
    final hasDigit = RegExp(r'[0-9]').hasMatch(cleaned);
    // Most standard plates have at least one letter and at least one digit
    return hasLetter && hasDigit;
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
