import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Downloads and silently applies a Windows MSI, then relaunches Lona.
class WindowsUpdateInstaller {
  static const defaultExePath = r'C:\Program Files\Lona\linkedup.exe';

  /// Download [msiUrl] to a temp file. Returns the local path.
  static Future<String> downloadMsi(
    String msiUrl, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final uri = Uri.parse(msiUrl);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/octet-stream');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'MSI download failed (${response.statusCode})',
          uri: uri,
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : null;
      final dir = await getTemporaryDirectory();
      final fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'lona-update.msi';
      final file = File('${dir.path}/$fileName');

      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Quit this process, run MSI silently, then relaunch [exePath].
  static Future<void> scheduleInstallAndExit({
    required String msiPath,
    String exePath = defaultExePath,
  }) async {
    final dir = await getTemporaryDirectory();
    final scriptPath = '${dir.path}/lona_apply_update.ps1';
    final normalizedMsi = msiPath.replaceAll("'", "''");
    final normalizedExe = exePath.replaceAll("'", "''");

    final script = '''
\$ErrorActionPreference = 'Stop'
Start-Sleep -Seconds 2
\$p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @(
  '/i', '$normalizedMsi',
  '/quiet',
  '/norestart',
  'INSTALLDESKTOPSHORTCUT=0'
) -PassThru -Wait
if (\$p.ExitCode -ne 0 -and \$p.ExitCode -ne 3010) {
  exit \$p.ExitCode
}
Start-Process -FilePath '$normalizedExe'
exit 0
''';

    await File(scriptPath).writeAsString(script);

    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}
