import 'dart:io';

import 'package:path/path.dart' as p;
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
  static String get logFilePath {
    final temp = Platform.environment['TEMP'] ?? r'C:\Temp';
    return p.join(temp, 'lona-update.log');
  }

  static String get msiLogFilePath {
    final temp = Platform.environment['TEMP'] ?? r'C:\Temp';
    return p.join(temp, 'lona-update-msi.log');
  }

  /// Elevated msiexec reads from here — not user Temp (1619 if left in %TEMP%).
  static String get stagingMsiPath {
    final programData = Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    return p.join(programData, 'Lona', 'lona-update.msi');
  }

  static String _psQuote(String value) => value.replaceAll("'", "''");

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
      final file = File(p.join(dir.path, fileName));

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
    final scriptPath = p.join(dir.path, 'lona_apply_update.ps1');
    final logPath = _psQuote(logFilePath);
    final msiLogPath = _psQuote(msiLogFilePath);
    final normalizedMsi = _psQuote(p.normalize(msiPath));
    final stagedMsi = _psQuote(stagingMsiPath);
    final normalizedExe = _psQuote(exePath);
    final legacyList = legacyExePaths
        .map((path) => "'${_psQuote(path)}'")
        .join(',');

    // perMachine MSI requires elevation; copy MSI to ProgramData first
    // (elevated msiexec often returns 1619 for packages in user Temp).
    final script = '''
\$ErrorActionPreference = 'Continue'
\$log = '$logPath'
\$msiLog = '$msiLogPath'
"" | Set-Content -Path \$log -Encoding UTF8
function Log([string]\$msg) {
  Add-Content -Path \$log -Value "\$(Get-Date -Format o) \$msg"
}
Log '=== lona_apply_update.ps1 started ==='
Log "MSI download: $normalizedMsi"
Log "MSI staged: $stagedMsi"
Log "Target exe: $normalizedExe"

\$hadDesktopShortcut = \$false
\$shell = New-Object -ComObject WScript.Shell
\$desktopDirs = @(\$shell.SpecialFolders('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')) | Select-Object -Unique
\$desktopShortcutDirs = @()
foreach (\$desktopDir in \$desktopDirs) {
  if (Test-Path (Join-Path \$desktopDir 'Lona.lnk')) {
    \$desktopShortcutDirs += \$desktopDir
  }
}
\$hadDesktopShortcut = \$desktopShortcutDirs.Count -gt 0
\$desktopShortcutFlag = if (\$hadDesktopShortcut) { '1' } else { '0' }
Log "Had desktop shortcut before update: \$hadDesktopShortcut"
if (\$hadDesktopShortcut) {
  Log "Shortcut location(s): \$(\$desktopShortcutDirs -join ', ')"
}

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

if (-not (Test-Path '$normalizedMsi')) {
  Log "ERROR: downloaded MSI missing: $normalizedMsi"
  exit 1619
}

\$stageDir = Split-Path -Parent '$stagedMsi'
New-Item -ItemType Directory -Force -Path \$stageDir | Out-Null
Copy-Item -Path '$normalizedMsi' -Destination '$stagedMsi' -Force
if (-not (Test-Path '$stagedMsi')) {
  Log "ERROR: failed to stage MSI at $stagedMsi"
  exit 1619
}
Log "Staged MSI size: \$((Get-Item '$stagedMsi').Length) bytes"

Log 'Starting elevated msiexec'
\$p = Start-Process -FilePath 'msiexec.exe' -Verb RunAs -PassThru -Wait -ArgumentList @(
  '/i', '$stagedMsi',
  '/quiet',
  '/norestart',
  '/L*v', \$msiLog,
  "INSTALLDESKTOPSHORTCUT=\$desktopShortcutFlag"
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

try { Remove-Item -Path '$stagedMsi' -Force -ErrorAction SilentlyContinue } catch {}

\$launch = '$normalizedExe'
if (-not (Test-Path \$launch)) {
  foreach (\$candidate in @($legacyList)) {
    if (Test-Path \$candidate) { \$launch = \$candidate; break }
  }
}
Log "Relaunch path: \$launch (exists=\$(Test-Path \$launch))"

if (\$hadDesktopShortcut -and (Test-Path \$launch)) {
  foreach (\$desktopDir in \$desktopShortcutDirs) {
    \$lnk = Join-Path \$desktopDir 'Lona.lnk'
    if (-not (Test-Path \$lnk)) {
      Log "Recreating desktop shortcut: \$lnk"
      try {
        \$wsh = New-Object -ComObject WScript.Shell
        \$shortcut = \$wsh.CreateShortcut(\$lnk)
        \$shortcut.TargetPath = \$launch
        \$shortcut.WorkingDirectory = Split-Path \$launch -Parent
        \$shortcut.Description = 'Lona'
        \$shortcut.Save()
      } catch {
        Log "Desktop shortcut recreate failed: \$(\$_.Exception.Message)"
      }
    }
  }
}

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
