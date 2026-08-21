import 'package:translator/translator.dart';

void main() async {
  final translator = GoogleTranslator();
  try {
    final translation = await translator.translate("Hello", to: 'zh');
    print("Success zh: \${translation.text}");
  } catch (e) {
    print("Error zh: $e");
  }

  try {
    final translation = await translator.translate("Hello", to: 'zh-cn');
    print("Success zh-cn: \${translation.text}");
  } catch (e) {
    print("Error zh-cn: $e");
  }

  try {
    final translation = await translator.translate("Hello", to: 'zh-tw');
    print("Success zh-tw: \${translation.text}");
  } catch (e) {
    print("Error zh-tw: $e");
  }
}
