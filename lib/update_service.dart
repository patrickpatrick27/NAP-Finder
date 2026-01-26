import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';

class GithubUpdateService {
  static const String _owner = "patrickpatrick27";
  static const String _repo = "nap_locator";
  
  // NOTE: For Public Repos, no token is needed!
  // This avoids the 404/403 errors and keeps your code safe.

  static Future<void> checkForUpdate(BuildContext context) async {
    print("🔍 [UpdateService] Checking for updates (Public Repo)...");
    
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      print("📱 [UpdateService] Current App Version: $currentVersion");

      // No headers needed for public repos
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      );
      
      print("🌐 [UpdateService] GitHub Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name']; 
        
        // Remove 'v' if present (v1.0.14 -> 1.0.14)
        String latestVersion = tagName.replaceAll('v', '');
        print("☁️ [UpdateService] GitHub Version: $latestVersion");

        // FIND THE APK URL
        String? apkUrl;
        List<dynamic> assets = data['assets'];
        print("📦 [UpdateService] Assets found: ${assets.length}");
        
        for (var asset in assets) {
          print("   - File: ${asset['name']}");
          if (asset['name'].toString().endsWith('.apk')) {
            apkUrl = asset['browser_download_url']; 
            print("   ✅ APK Found: $apkUrl");
            break;
          }
        }

        if (apkUrl == null) {
          print("❌ [UpdateService] Release found, but NO APK file attached!");
          return;
        }

        bool isNewer = _isNewer(latestVersion, currentVersion);
        print("🤔 [UpdateService] Is $latestVersion > $currentVersion? $isNewer");

        if (isNewer) {
          print("🚀 [UpdateService] Triggering Update Dialog!");
          _showUpdateDialog(context, latestVersion, apkUrl);
        }
      } else {
        print("❌ [UpdateService] API Error: ${response.body}");
      }
    } catch (e) {
      print("❌ [UpdateService] CRASH: $e");
    }
  }

  static bool _isNewer(String latest, String current) {
    try {
      List<int> l = latest.split('.').map(int.parse).toList();
      List<int> c = current.split('.').map(int.parse).toList();

      for (int i = 0; i < l.length; i++) {
        if (i >= c.length) return true;
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (e) {
      print("⚠️ [UpdateService] Version parse error: $e");
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UpdateProgressDialog(version: version, apkUrl: apkUrl);
      },
    );
  }
}

// --- NEW WIDGET: HANDLES DOWNLOAD & INSTALL ---
class _UpdateProgressDialog extends StatefulWidget {
  final String version;
  final String apkUrl;

  const _UpdateProgressDialog({required this.version, required this.apkUrl});

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  String _status = "Ready to download";
  double _progress = 0.0;
  bool _isDownloading = false;
  final Dio _dio = Dio();
  final FlutterAppInstaller _installer = FlutterAppInstaller();

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = "Downloading...";
    });

    try {
      Directory tempDir = await getTemporaryDirectory();
      String savePath = "${tempDir.path}/update.apk";

      await _dio.download(
        widget.apkUrl, 
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _status = "Downloading: ${( _progress * 100).toStringAsFixed(0)}%";
            });
          }
        },
      );

      setState(() => _status = "Installing...");
      await _installer.installApk(filePath: savePath);
      
      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() {
        _status = "Error: $e";
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update to ${widget.version} 📲"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("A new version is available. Click update to download and install automatically."),
          const SizedBox(height: 20),
          if (_isDownloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
            Text(_status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
        if (!_isDownloading)
          FilledButton(
            onPressed: _startDownload,
            child: const Text("Update Now"),
          ),
      ],
    );
  }
}