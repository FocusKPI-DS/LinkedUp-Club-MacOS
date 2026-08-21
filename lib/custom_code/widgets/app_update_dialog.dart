import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:linkedup/custom_code/services/app_update_service.dart';
import 'package:linkedup/custom_code/services/windows_update_installer.dart';

/// Shared update prompts across platforms.
class AppUpdateDialog {
  AppUpdateDialog._();

  static bool _promptInFlight = false;

  /// Checks for a newer version and shows the platform update dialog.
  ///
  /// Non-forced calls show the prompt at most once per version (a one-time
  /// popup), so users aren't nagged on every launch. Forced calls (e.g. the
  /// manual "Check for updates" button) always show when an update exists.
  /// No-op on web and unsupported platforms.
  static Future<void> maybeShowUpdatePrompt(
    BuildContext context, {
    bool force = false,
  }) async {
    if (kIsWeb) return;
    if (!(Platform.isIOS || Platform.isMacOS || Platform.isWindows)) return;
    if (_promptInFlight) return;
    _promptInFlight = true;
    try {
      // Fall back to the last known result so a rate-limited check (e.g. when
      // another component already checked this interval) still prompts.
      final hasUpdate = await AppUpdateService.checkForUpdate(force: force) ??
          AppUpdateService.lastUpdateAvailable;
      if (hasUpdate != true) return;

      final version = AppUpdateService.pendingLatestVersion ?? '';
      if (!force && await AppUpdateService.hasPromptedForVersion(version)) {
        return;
      }
      if (!context.mounted) return;

      // Mark before showing so a race can't produce two popups.
      if (!force && version.isNotEmpty) {
        await AppUpdateService.markPromptedForVersion(version);
      }
      if (!context.mounted) return;

      if (Platform.isMacOS) {
        await showMac(context);
      } else if (Platform.isWindows) {
        await showWindows(context);
      } else if (Platform.isIOS) {
        await showIOS(context);
      }
    } catch (_) {
      // Never let update prompting crash a page load.
    } finally {
      _promptInFlight = false;
    }
  }

  static Widget _releaseNotesMarkdown(
    String releaseNotes, {
    bool cupertino = false,
    double maxHeight = 220,
  }) {
    final baseStyle = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: cupertino ? CupertinoColors.secondaryLabel : const Color(0xFF4B5563),
    );
    return MarkdownBody(
      data: releaseNotes,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        h1: baseStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        h2: baseStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        h3: baseStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        listBullet: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w600),
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: const Color(0xFFF3F4F6),
        ),
        tableHead: baseStyle.copyWith(fontWeight: FontWeight.w600),
        tableBody: baseStyle,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }

  static Widget _releaseNotesBox(String releaseNotes, {bool cupertino = false}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(right: 4),
          child: _releaseNotesMarkdown(releaseNotes, cupertino: cupertino),
        ),
      ),
    );
  }

  static Widget _versionBadgeRow({
    required String label,
    required String version,
    required Color badgeColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            'v$version',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _updateDialogHeader({
    required String version,
    bool compact = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.system_update_rounded,
          color: const Color(0xFF3B82F6),
          size: compact ? 22 : 24,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Lona Update v$version Available!',
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

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
                _releaseNotesMarkdown(releaseNotes, cupertino: true),
              ],
            ],
          ),
        ),
        actions: [
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
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 440, maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _updateDialogHeader(version: version),
                const SizedBox(height: 12),
                const Text(
                  'A Lona update is available.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _versionBadgeRow(
                  label: 'Current Version',
                  version: currentVersion,
                  badgeColor: const Color(0xFFDC2626),
                ),
                const SizedBox(height: 14),
                _versionBadgeRow(
                  label: 'New Version',
                  version: version,
                  badgeColor: const Color(0xFF16A34A),
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Release notes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _releaseNotesBox(releaseNotes),
                ],
                const SizedBox(height: 18),
                const Text(
                  'The app will close and install the update, then reopen.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          await _runWindowsInstall(context, downloadUrl);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Install Update',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// iOS: prompt to update via the App Store. Mirrors the established alert.
  static Future<void> showIOS(BuildContext context) async {
    try {
      await AdaptiveAlertDialog.show(
        context: context,
        title: 'Update Available',
        message:
            'A new version of Lona is available on the App Store. Please update to continue using the latest features and improvements.',
        icon: 'arrow.down.circle.fill',
        actions: [
          AlertAction(
            title: 'Later',
            style: AlertActionStyle.cancel,
            onPressed: () {},
          ),
          AlertAction(
            title: 'Update',
            style: AlertActionStyle.primary,
            onPressed: () async {
              final appStoreUrl = AppUpdateService.getAppStoreUrl();
              final uri = Uri.parse(appStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      );
    } catch (_) {}
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
