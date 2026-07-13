import 'dart:io';

import 'package:path/path.dart' as p;

/// Verifies cmd /c start keeps the child alive after exit(0) (same as updater).
Future<void> main() async {
  final temp = Platform.environment['TEMP'] ?? r'C:\Temp';
  final log = p.join(temp, 'lona-dart-detach.log');
  final scriptPath = p.join(temp, 'lona-dart-detach.ps1');
  const script = r'''
Add-Content -Path "$env:TEMP\lona-dart-detach.log" -Value "$(Get-Date -Format o) child start pid=$PID"
Start-Sleep -Seconds 5
Add-Content -Path "$env:TEMP\lona-dart-detach.log" -Value "$(Get-Date -Format o) child still alive"
''';
  await File(scriptPath).writeAsString(script);
  try {
    await File(log).delete();
  } catch (_) {}

  await Process.start(
    'cmd.exe',
    [
      '/c',
      'start',
      '',
      '/min',
      'powershell.exe',
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

  await Future<void>.delayed(const Duration(milliseconds: 500));
  exit(0);
}
