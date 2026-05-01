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

  static Future<void> checkForUpdate(BuildContext context) async {
    print("🔍 [UpdateService] Checking for updates...");
    
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? tagName = data['tag_name']; 
        if (tagName == null) return;

        String latestVersion = tagName.replaceAll('v', '');
        
        String? apkUrl;
        List<dynamic> assets = data['assets'] ?? [];
        for (var asset in assets) {
          if (asset['name'].toString().toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url']; 
            break;
          }
        }

        if (apkUrl == null) return;

        bool isNewer = _isNewer(latestVersion, currentVersion);
        if (isNewer && context.mounted) {
          _showUpdateDialog(context, latestVersion, apkUrl);
        }
      } 
    } catch (e) {
      print("❌ [UpdateService] Exception: $e");
    }
  }

  static bool _isNewer(String latest, String current) {
    try {
      // Robust parsing: handles 1.0 vs 1.0.0 vs 1.0.0+1
      List<String> lParts = latest.split('+')[0].split('.');
      List<String> cParts = current.split('+')[0].split('.');

      int maxLength = lParts.length > cParts.length ? lParts.length : cParts.length;

      for (int i = 0; i < maxLength; i++) {
        int lNum = i < lParts.length ? (int.tryParse(lParts[i]) ?? 0) : 0;
        int cNum = i < cParts.length ? (int.tryParse(cParts[i]) ?? 0) : 0;

        if (lNum > cNum) return true;
        if (lNum < cNum) return false;
      }

      // If main versions are equal, check build numbers (+1, +2 etc)
      int lBuild = latest.contains('+') ? (int.tryParse(latest.split('+')[1]) ?? 0) : 0;
      int cBuild = current.contains('+') ? (int.tryParse(current.split('+')[1]) ?? 0) : 0;
      
      return lBuild > cBuild;

    } catch (e) {
      print("⚠️ Version comparison error: $e");
      return false;
    }
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

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = "Downloading...";
    });

    try {
      Directory tempDir = await getTemporaryDirectory();
      String savePath = "${tempDir.path}/update.apk";

      // Delete old file if exists
      final file = File(savePath);
      if (await file.exists()) await file.delete();

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

      if (!mounted) return;
      setState(() => _status = "Installing...");
      
      // Using constructor-based instance for v1.x of flutter_app_installer
      final installer = FlutterAppInstaller();
      await installer.installApk(filePath: savePath);
      
      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "Error: $e";
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update to ${widget.version} 📲"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("A new version is available."),
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
