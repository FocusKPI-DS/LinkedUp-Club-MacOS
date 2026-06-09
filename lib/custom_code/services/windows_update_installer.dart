import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Downloads and silently applies a Windows MSI, then relaunches Lona.
class WindowsUpdateInstaller {
  /// MSI harvest installs under INSTALLFOLDER\Release\ (see installer/Harvest.wxs).
  static const defaultExePath =
      r'C:\Program Files\Lona\Release\lona.exe';

  static const legacyExePaths = [
    r'C:\Program Files\Lona\lona.exe',
    r'C:\Program Files\Lona\Release\linkedup.exe',
    r'C:\Program Files\Lona\linkedup.exe',
  ];

  /// Where the post-exit PowerShell script writes diagnostics (also MSI verbose log).
  static String get logFilePath =>
      '${Platform.environment['TEMP'] ?? r'C:\Temp'}\lona-update.log';

  static String get msiLogFilePath =>
      '${Platform.environment['TEMP'] ?? r'C:\Temp'}\lona-update-msi.log';

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
      request.headers.set('User-Agent', 'Lona-Updater');
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

      final size = await file.length();
      if (size < 1024) {
        throw HttpException(
          'MSI download looks too small ($size bytes)',
          uri: uri,
        );
      }
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Quit this process, run MSI silently (elevated), then relaunch Lona.
  static Future<void> scheduleInstallAndExit({
    required String msiPath,
    String exePath = defaultExePath,
  }) async {
    final dir = await getTemporaryDirectory();
    final scriptPath = '${dir.path}/lona_apply_update.ps1';
    final logPath = logFilePath.replaceAll("'", "''");
    final msiLogPath = msiLogFilePath.replaceAll("'", "''");
    final normalizedMsi = msiPath.replaceAll("'", "''");
    final normalizedExe = exePath.replaceAll("'", "''");
    final legacyList = legacyExePaths
        .map((p) => "'${p.replaceAll("'", "''")}'")
        .join(',');

    // perMachine MSI requires elevation; kill lona/linkedup before install;
    // write logs under %TEMP% because the Flutter process exits immediately.
    final script = '''
\$ErrorActionPreference = 'Continue'
\$log = '$logPath'
\$msiLog = '$msiLogPath'
"" | Set-Content -Path \$log -Encoding UTF8
function Log([string]\$msg) {
  Add-Content -Path \$log -Value "\$(Get-Date -Format o) \$msg"
}
Log '=== lona_apply_update.ps1 started ==='
Log "MSI: $normalizedMsi"
Log "Target exe: $normalizedExe"

foreach (\$name in @('lona','linkedup')) {
  Get-Process -Name \$name -ErrorAction SilentlyContinue | ForEach-Object {
    Log "Stopping \$name pid \$(\$_.Id)"
    Stop-Process -Id \$_.Id -Force -ErrorAction SilentlyContinue
  }
}

\$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt \$deadline) {
  \$running = @(Get-Process -Name 'lona','linkedup' -ErrorAction SilentlyContinue)
  if (-not \$running) { break }
  Start-Sleep -Milliseconds 500
}
Log 'Process wait complete'

Start-Sleep -Seconds 2

Log "Starting elevated msiexec"
\$p = Start-Process -FilePath 'msiexec.exe' -Verb RunAs -PassThru -Wait -ArgumentList @(
  '/i', '$normalizedMsi',
  '/quiet',
  '/norestart',
  '/L*v', \$msiLog,
  'INSTALLDESKTOPSHORTCUT=0'
)
\$code = \$p.ExitCode
Log "msiexec exit code: \$code"

if (\$code -ne 0 -and \$code -ne 3010) {
  Log 'Install failed'
  try {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
      "Lona update failed (exit \$code).`n`nLogs:`n\$log`n\$msiLog",
      'Lona Update',
      'OK',
      'Error'
    ) | Out-Null
  } catch {
    Log "Could not show error dialog: \$(\$_.Exception.Message)"
  }
  exit \$code
}

\$launch = '$normalizedExe'
if (-not (Test-Path \$launch)) {
  foreach (\$candidate in @($legacyList)) {
    if (Test-Path \$candidate) { \$launch = \$candidate; break }
  }
}
Log "Relaunch path: \$launch (exists=\$(Test-Path \$launch))"

if (Test-Path \$launch) {
  Start-Process -FilePath \$launch
  Log 'Relaunched Lona'
} else {
  Log 'ERROR: Lona executable not found after install'
  try {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
      "Update installed but Lona.exe was not found.`nExpected under Program Files\\Lona",
      'Lona Update',
      'OK',
      'Warning'
    ) | Out-Null
  } catch {}
}
Log '=== done ==='
exit 0
''';

    await File(scriptPath).writeAsString(script);

    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        scriptPath,
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}
