import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:linkedup/custom_code/services/app_update_service.dart';
import 'package:linkedup/custom_code/services/windows_update_installer.dart';

/// Shared update prompts for desktop platforms.
class AppUpdateDialog {
  AppUpdateDialog._();

  static Future<void> showMac(BuildContext context) async {
    final releaseInfo =
        AppUpdateService.pendingReleaseInfo ??
            await AppUpdateService.fetchGitHubLatestRelease();
    if (releaseInfo == null || !context.mounted) return;

    final version = releaseInfo['version'] ?? '';
    final downloadUrl = releaseInfo['downloadUrl'] ?? '';
    final releaseNotes = releaseInfo['releaseNotes'] ?? '';
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    if (!context.mounted) return;

    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.system_update_rounded,
                color: Color(0xFF3B82F6), size: 22),
            SizedBox(width: 8),
            Text('Update Available'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lona v$version is available.\nYou are currently on v$currentVersion.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              if (releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseNotes,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Skip This Version'),
            onPressed: () {
              AppUpdateService.skipVersion(version);
              Navigator.pop(dialogCtx);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Later'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Download Update'),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (downloadUrl.isNotEmpty) {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  static Future<void> showWindows(BuildContext context) async {
    final releaseInfo =
        AppUpdateService.pendingReleaseInfo ??
            await AppUpdateService.fetchWindowsReleaseInfo();
    if (releaseInfo == null || !context.mounted) return;

    final version = releaseInfo['version'] ?? '';
    final downloadUrl = releaseInfo['downloadUrl'] ?? '';
    final releaseNotes = releaseInfo['releaseNotes'] ?? '';
    if (downloadUrl.isEmpty) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lona v$version is available.\nYou are on v$currentVersion.',
            ),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    releaseNotes,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'The app will close and install silently, then reopen.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppUpdateService.skipVersion(version);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (context.mounted) {
                await _runWindowsInstall(context, downloadUrl);
              }
            },
            child: const Text('Install Update'),
          ),
        ],
      ),
    );
  }

  static Future<void> _runWindowsInstall(
    BuildContext context,
    String downloadUrl,
  ) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Downloading update…')),
          ],
        ),
      ),
    );

    try {
      final msiPath = await WindowsUpdateInstaller.downloadMsi(downloadUrl);
      if (context.mounted) Navigator.pop(context);
      await WindowsUpdateInstaller.scheduleInstallAndExit(msiPath: msiPath);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }
}
