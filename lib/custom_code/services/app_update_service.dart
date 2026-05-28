import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to check for app updates.
/// - iOS: Checks the App Store via iTunes Search API
/// - macOS: Checks GitHub Releases API for latest DMG
class AppUpdateService {
  // App Store ID for Lona Club (iOS)
  static const String _appStoreId = '6747595642';
  static const String _appStoreUrl =
      'https://apps.apple.com/us/app/lona-club/id$_appStoreId';

  // GitHub repository for macOS releases
  static const String _githubOwner = 'FocusKPI-DS';
  static const String _githubRepo = 'LinkedUp-Club-MacOS';

  // Rate limiting: check at most once every 4 hours
  static const String _lastCheckKey = 'app_update_last_check';
  static const String _skippedVersionKey = 'app_update_skipped_version';
  static const Duration _checkInterval = Duration(hours: 4);

  /// Check if a new version is available.
  /// Returns null if check fails, true if update available, false if up to date.
  static Future<bool?> checkForUpdate() async {
    if (kIsWeb) return null;

    // Rate limiting
    if (!await _shouldCheck()) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!kIsWeb && Platform.isMacOS) {
        // macOS: Check GitHub Releases
        final info = await fetchGitHubLatestRelease();
        if (info == null) return null;

        final latestVersion = info['version'] as String;

        // Check if user skipped this version
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString(_skippedVersionKey);
        if (skipped == latestVersion) return false;

        await _recordCheck();
        return _isVersionNewer(latestVersion, currentVersion);
      } else if (Platform.isIOS) {
        // iOS: Check App Store
        final latestVersion = await _fetchLatestVersionFromAppStore();
        if (latestVersion == null) return null;

        await _recordCheck();
        return _isVersionNewer(latestVersion, currentVersion);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch latest release info from GitHub Releases API.
  /// Returns a map with version, downloadUrl, releaseNotes, htmlUrl.
  static Future<Map<String, String>?> fetchGitHubLatestRelease() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? '';
        final version = tagName.replaceFirst('v', '');
        final body = data['body'] as String? ?? '';
        final htmlUrl = data['html_url'] as String? ?? '';

        // Find the DMG asset download URL
        String downloadUrl = '';
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.toLowerCase().endsWith('.dmg')) {
              downloadUrl =
                  asset['browser_download_url'] as String? ?? '';
              break;
            }
          }
        }

        // Fallback to release page if no DMG asset found
        if (downloadUrl.isEmpty) {
          downloadUrl = htmlUrl;
        }

        return {
          'version': version,
          'downloadUrl': downloadUrl,
          'releaseNotes': body,
          'htmlUrl': htmlUrl,
        };
      }
    } catch (e) {
      print('Error fetching GitHub release: $e');
    }
    return null;
  }

  /// Fetch the latest version from the App Store using iTunes Search API
  static Future<String?> _fetchLatestVersionFromAppStore() async {
    try {
      final url = Uri.parse(
        'https://itunes.apple.com/lookup?id=$_appStoreId',
      );

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final appInfo = results[0] as Map<String, dynamic>;
          return appInfo['version'] as String?;
        }
      }
    } catch (e) {
      print('Error fetching app version from App Store: $e');
    }
    return null;
  }

  /// Compare two version strings (e.g., "1.9.25" vs "1.9.24")
  /// Returns true if version1 is newer than version2
  static bool _isVersionNewer(String version1, String version2) {
    try {
      final v1 =
          version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final v2 =
          version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Pad with zeros
      while (v1.length < v2.length) v1.add(0);
      while (v2.length < v1.length) v2.add(0);

      for (int i = 0; i < v1.length; i++) {
        if (v1[i] > v2[i]) return true;
        if (v1[i] < v2[i]) return false;
      }
      return false; // Equal
    } catch (e) {
      return false;
    }
  }

  /// Check if enough time has passed since the last update check
  static Future<bool> _shouldCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      return (now - lastCheck) > _checkInterval.inMilliseconds;
    } catch (e) {
      return true; // Check if we can't read prefs
    }
  }

  /// Record that we just performed an update check
  static Future<void> _recordCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Mark a version as skipped (user chose "Skip This Version")
  static Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedVersionKey, version);
    } catch (_) {}
  }

  /// Get the App Store URL for the app (iOS)
  static String getAppStoreUrl() => _appStoreUrl;
}

