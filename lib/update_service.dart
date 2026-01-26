import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class GithubUpdateService {
  static const String _owner = "patrickpatrick27";
  static const String _repo = "nap_locator";
  
  // PASTE YOUR READ-ONLY TOKEN HERE
  static const String _token = "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"; 

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name']; 
        String downloadUrl = data['html_url']; // This goes to the release page
        
        // If your tag is v1.0.0, this makes it 1.0.0
        String latestVersion = tagName.replaceAll('v', '');

        if (_isNewer(latestVersion, currentVersion)) {
          // If the Github asset is an APK, try to find direct link
          // (Optional: loop through data['assets'] to find .apk)
          _showUpdateDialog(context, latestVersion, downloadUrl);
        }
      }
    } catch (e) {
      print("Update check error: $e");
    }
  }

  static bool _isNewer(String latest, String current) {
    List<int> l = latest.split('.').map(int.parse).toList();
    List<int> c = current.split('.').map(int.parse).toList();

    for (int i = 0; i < l.length; i++) {
      if (i >= c.length) return true;
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("New Update Available! 📲"),
        content: Text("Version $version is ready.\n\nThis update requires a full reinstall."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }
}