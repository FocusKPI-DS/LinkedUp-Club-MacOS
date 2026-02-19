import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to check for app updates from the App Store
class AppUpdateService {
  // App Store ID for Lona Club
  static const String _appStoreId = '6747595642';
  static const String _appStoreUrl = 'https://apps.apple.com/us/app/lona-club/id$_appStoreId';

  /// Check if a new version is available on the App Store
  /// Returns null if check fails, true if update is available, false if up to date
  static Future<bool?> checkForUpdate() async {
    // Only check on iOS
    if (kIsWeb || !Platform.isIOS) {
      return null;
    }

    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch latest version from App Store
      final latestVersion = await _fetchLatestVersionFromAppStore();
      if (latestVersion == null) {
        return null;
      }
      
      // Compare versions
      return _isVersionNewer(latestVersion, currentVersion);
    } catch (e) {
      return null;
    }
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
          final version = appInfo['version'] as String?;
          return version;
        }
      }
    } catch (e) {
      print('Error fetching app version from App Store: $e');
    }
    return null;
  }

  /// Compare two version strings (e.g., "1.8.3" vs "1.8.4")
  /// Returns true if version1 is newer than version2
  static bool _isVersionNewer(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Pad with zeros to make lengths equal
      while (v1Parts.length < v2Parts.length) {
        v1Parts.add(0);
      }
      while (v2Parts.length < v1Parts.length) {
        v2Parts.add(0);
      }

      // Compare each part
      for (int i = 0; i < v1Parts.length; i++) {
        if (v1Parts[i] > v2Parts[i]) {
          return true;
        } else if (v1Parts[i] < v2Parts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }

  /// Get the App Store URL for the app
  static String getAppStoreUrl() {
    return _appStoreUrl;
  }
}





