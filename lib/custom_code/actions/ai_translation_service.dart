import 'package:translator/translator.dart';
import '../../app_state.dart';

Future<String> translateOutgoingMessage(String originalText) async {
  final prefs = FFAppState();

  if (!prefs.aiTranslationEnabled || originalText.trim().isEmpty) {
    return originalText;
  }

  final targetLangCode = prefs.aiTranslationTargetLanguage;

  try {
    final translator = GoogleTranslator();
    var translation = await translator.translate(
      originalText,
      to: targetLangCode,
    );
    return translation.text;
  } catch (e) {
    print('Translation Exception: $e');
    throw Exception('Translation failed: $e');
  }
}
