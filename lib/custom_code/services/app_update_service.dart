import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to check for app updates via the App Store (both iOS and macOS).
class AppUpdateService {
  // App Store ID for Lona Club
  static const String _appStoreId = '6747595642';
  static const String _appStoreUrl =
      'https://apps.apple.com/us/app/lona-club/id$_appStoreId';

  // Rate limiting: check at most once every 4 hours
  static const String _lastCheckKey = 'app_update_last_check';
  static const String _skippedVersionKey = 'app_update_skipped_version';
  static const Duration _checkInterval = Duration(hours: 4);

  /// Check if a new version is available on the App Store.
  /// Returns null if check fails, true if update available, false if up to date.
  static Future<bool?> checkForUpdate() async {
    if (kIsWeb) return null;

    // Rate limiting
    if (!await _shouldCheck()) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Both iOS and macOS check the App Store
      final latestVersion = await fetchLatestVersionFromAppStore();
      if (latestVersion == null) return null;

      // Check if user skipped this version
      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getString(_skippedVersionKey);
      if (skipped == latestVersion) return false;

      await _recordCheck();
      return _isVersionNewer(latestVersion, currentVersion);
    } catch (e) {
      return null;
    }
  }

  /// Fetch the latest version string from the App Store using iTunes Search API.
  /// Returns the version string (e.g. "1.9.30") or null on failure.
  static Future<String?> fetchLatestVersionFromAppStore() async {
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

  /// Get the App Store URL for the app
  static String getAppStoreUrl() => _appStoreUrl;

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}

