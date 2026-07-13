import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:linkedup/utils/debug_log.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Checks GitHub Releases for updates and applies them per platform.
/// - iOS: App Store
/// - macOS: latest release DMG
/// - Windows: [lona-windows.json] manifest + MSI
class AppUpdateService {
  static const String _appStoreId = '6747595642';
  static const String _appStoreUrl =
      'https://apps.apple.com/us/app/lona-club/id$_appStoreId';

  static const String _githubOwner = 'FocusKPI-DS';
  static const String _githubRepo = 'LinkedUp-Club-MacOS';
  static const String _windowsManifestAsset = 'lona-windows.json';

  static const String _lastCheckKey = 'app_update_last_check';
  static const String _skippedVersionKey = 'app_update_skipped_version';

  /// Cached release info from the most recent successful check.
  static Map<String, String>? pendingReleaseInfo;

  /// How often to poll for updates.
  static Duration get checkInterval {
    if (!kIsWeb && Platform.isWindows) {
      return const Duration(hours: 1);
    }
    return const Duration(hours: 4);
  }

  /// Returns null on failure, true if newer version exists, false if up to date.
  static Future<bool?> checkForUpdate({bool force = false}) async {
    if (kIsWeb) return null;
    if (!force && !await _shouldCheck()) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!kIsWeb && Platform.isMacOS) {
        final info = await fetchGitHubLatestRelease(assetExtension: '.dmg');
        if (info == null) return null;
        pendingReleaseInfo = info;
        return _evaluateVersion(info['version'] ?? '', currentVersion);
      }

      if (Platform.isIOS) {
        final latestVersion = await _fetchLatestVersionFromAppStore();
        if (latestVersion == null) return null;
        await _recordCheck();
        return _isVersionNewer(latestVersion, currentVersion);
      }

      if (Platform.isWindows) {
        final info = await fetchWindowsReleaseInfo();
        if (info == null) return null;
        pendingReleaseInfo = info;
        return _evaluateWindowsUpdate(
          info,
          currentVersion,
          packageInfo.buildNumber,
        );
      }

      return null;
    } catch (e) {
      debugLog('AppUpdateService.checkForUpdate error: $e');
      return null;
    }
  }

  static Future<bool?> _evaluateVersion(
    String latestVersion,
    String currentVersion,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_skippedVersionKey);
    if (skipped == latestVersion) return false;

    await _recordCheck();
    final newer = _isVersionNewer(latestVersion, currentVersion);
    if (newer) {
      debugLog(
        'AppUpdateService: update available ($currentVersion -> $latestVersion)',
      );
    }
    return newer;
  }

  static Future<bool?> _evaluateWindowsUpdate(
    Map<String, String> info,
    String currentVersion,
    String currentBuild,
  ) async {
    final latestVersion = info['version'] ?? '';
    final latestBuild = info['buildNumber'] ?? '';
    if (latestVersion.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_skippedVersionKey);
    if (skipped == latestVersion ||
        (latestBuild.isNotEmpty && skipped == '$latestVersion+$latestBuild')) {
      return false;
    }

    await _recordCheck();
    final newer = _isUpdateNewer(
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      currentVersion: currentVersion,
      currentBuild: currentBuild,
    );
    if (newer) {
      debugLog(
        'AppUpdateService: update available '
        '($currentVersion+$currentBuild -> $latestVersion+$latestBuild)',
      );
    }
    return newer;
  }

  static bool _isUpdateNewer({
    required String latestVersion,
    required String latestBuild,
    required String currentVersion,
    required String currentBuild,
  }) {
    if (_isVersionNewer(latestVersion, currentVersion)) return true;
    if (_isVersionNewer(currentVersion, latestVersion)) return false;

    if (latestBuild.isEmpty || currentBuild.isEmpty) return false;
    final latest = int.tryParse(latestBuild) ?? 0;
    final current = int.tryParse(currentBuild) ?? 0;
    return latest > current;
  }

  /// macOS: latest non-prerelease GitHub release with a DMG asset.
  static Future<Map<String, String>?> fetchGitHubLatestRelease({
    String assetExtension = '.dmg',
  }) async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      return _releaseMapFromGitHubJson(data, assetExtension: assetExtension);
    } catch (e) {
      debugLog('Error fetching GitHub release: $e');
    }
    return null;
  }

  /// Windows: newest GitHub release that ships [lona-windows.json] + an MSI.
  static Future<Map<String, String>?> fetchWindowsReleaseInfo() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases?per_page=20',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugLog(
          'Windows update: releases API returned ${response.statusCode}',
        );
        return null;
      }

      final releases = json.decode(response.body) as List<dynamic>;
      for (final raw in releases) {
        final release = raw as Map<String, dynamic>;
        final assets = release['assets'] as List<dynamic>? ?? [];
        final manifestAsset = _findAsset(assets, _windowsManifestAsset);
        if (manifestAsset == null) continue;

        final manifestUrl =
            manifestAsset['browser_download_url'] as String? ?? '';
        if (manifestUrl.isEmpty) continue;

        final manifest = await _fetchJson(manifestUrl);
        if (manifest == null) continue;

        final version = manifest['version']?.toString() ?? '';
        if (version.isEmpty) continue;

        final msiFileName = manifest['msiFileName']?.toString() ?? '';
        String downloadUrl = manifest['msiUrl']?.toString() ?? '';

        if (downloadUrl.isEmpty && msiFileName.isNotEmpty) {
          final msiAsset = _findAsset(assets, msiFileName);
          downloadUrl = msiAsset?['browser_download_url'] as String? ?? '';
        }
        if (downloadUrl.isEmpty) {
          final msiAsset = _findAssetByExtension(assets, '.msi');
          downloadUrl = msiAsset?['browser_download_url'] as String? ?? '';
        }
        if (downloadUrl.isEmpty) continue;

        final tagName = release['tag_name'] as String? ?? '';
        final htmlUrl = release['html_url'] as String? ?? '';
        final buildNumber = manifest['buildNumber']?.toString() ?? '';
        final releaseNotes = manifest['releaseNotes']?.toString() ?? '';

        return {
          'version': version,
          'buildNumber': buildNumber,
          'downloadUrl': downloadUrl,
          'releaseNotes': releaseNotes,
          'htmlUrl': htmlUrl,
          'tagName': tagName,
          'msiFileName': msiFileName,
        };
      }
    } catch (e) {
      debugLog('Error fetching Windows release info: $e');
    }
    return null;
  }

  static Map<String, dynamic>? _findAsset(
    List<dynamic> assets,
    String fileName,
  ) {
    for (final raw in assets) {
      final asset = raw as Map<String, dynamic>;
      if ((asset['name'] as String? ?? '').toLowerCase() ==
          fileName.toLowerCase()) {
        return asset;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findAssetByExtension(
    List<dynamic> assets,
    String ext,
  ) {
    for (final raw in assets) {
      final asset = raw as Map<String, dynamic>;
      final name = asset['name'] as String? ?? '';
      if (name.toLowerCase().endsWith(ext.toLowerCase())) {
        return asset;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchJson(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode != 200) return null;
      final body = response.body.replaceFirst('\uFEFF', '');
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      debugLog('Error fetching manifest $url: $e');
      return null;
    }
  }

  static Map<String, String>? _releaseMapFromGitHubJson(
    Map<String, dynamic> data, {
    required String assetExtension,
  }) {
    final tagName = data['tag_name'] as String? ?? '';
    final version = tagName.replaceFirst(RegExp('^v'), '');
    final body = data['body'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? '';

    String downloadUrl = '';
    final assets = data['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final raw in assets) {
        final name = raw['name'] as String? ?? '';
        if (name.toLowerCase().endsWith(assetExtension.toLowerCase())) {
          downloadUrl = raw['browser_download_url'] as String? ?? '';
          break;
        }
      }
    }
    if (downloadUrl.isEmpty) downloadUrl = htmlUrl;

    return {
      'version': version,
      'downloadUrl': downloadUrl,
      'releaseNotes': body,
      'htmlUrl': htmlUrl,
      'tagName': tagName,
    };
  }

  static Future<String?> _fetchLatestVersionFromAppStore() async {
    try {
      final url = Uri.parse(
        'https://itunes.apple.com/lookup?id=$_appStoreId',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results[0]['version'] as String?;
        }
      }
    } catch (e) {
      debugLog('Error fetching app version from App Store: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String version1, String version2) {
    try {
      final v1 =
          version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final v2 =
          version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (v1.length < v2.length) v1.add(0);
      while (v2.length < v1.length) v2.add(0);
      for (int i = 0; i < v1.length; i++) {
        if (v1[i] > v2[i]) return true;
        if (v1[i] < v2[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _shouldCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      return (now - lastCheck) > checkInterval.inMilliseconds;
    } catch (e) {
      return true;
    }
  }

  static Future<void> _recordCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedVersionKey, version);
    } catch (_) {}
  }

  static String getAppStoreUrl() => _appStoreUrl;
}
