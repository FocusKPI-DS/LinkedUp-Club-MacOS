// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:url_launcher/url_launcher.dart';

Future<void> openEmailApp(
  String senderEmail,
  String receiverEmail,
) async {
  final subject = Uri.encodeComponent('Hello from $senderEmail');
  final body = Uri.encodeComponent('Hi, this is a message from $senderEmail.');
  final emailUri =
      Uri.parse('mailto:$receiverEmail?subject=$subject&body=$body');

  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  } else {
    throw 'Could not open email app';
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
