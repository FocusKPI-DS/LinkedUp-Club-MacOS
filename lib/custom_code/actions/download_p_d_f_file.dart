// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io' show File, Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String?> downloadPDFFile(
  BuildContext context,
  String? link,
  bool promptToOpen,
  bool openImmediately,
) async {
  if (link == null || link.isEmpty) {
    debugPrint('Download link is null or empty.');
    return null;
  }

  // Web: open in a new tab (no local path)
  if (kIsWeb) {
    final ok =
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF in browser.')),
      );
    }
    return link; // on web we don’t have a saved path
  }

  try {
    final uri = Uri.parse(link);
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      debugPrint('Failed to download file: ${resp.statusCode}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed (${resp.statusCode}).')),
        );
      }
      return null;
    }

    // Ensure a .pdf filename
    var name = p.basename(uri.path);
    if (name.isEmpty || !name.toLowerCase().endsWith('.pdf')) {
      name = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }

    String filePath;
    File file;

    // Desktop: Prompt user to save file
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: name,
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        // User canceled
        return null;
      }
      filePath = outputFile;
      file = File(filePath);
    } else {
      // Mobile: Save to documents directory
      final dir = await getApplicationDocumentsDirectory();
      filePath = p.join(dir.path, name);
      file = File(filePath);
    }

    await file.writeAsBytes(resp.bodyBytes);
    debugPrint('File downloaded to $filePath');

    Future<void> openNow() async {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t open PDF: ${result.message}')),
        );
      }
    }

    if (openImmediately) {
      await openNow();
    } else if (promptToOpen && context.mounted) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download complete'),
          content: Text('Open “${p.basename(filePath)}” now?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Later')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Open')),
          ],
        ),
      );
      if (shouldOpen == true) await openNow();
    }

    return filePath;
  } catch (e) {
    debugPrint('Error downloading file: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed.')),
      );
    }
    return null;
  }
}
