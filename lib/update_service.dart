import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart'; // IMPORT THIS

class GithubUpdateService {
  static const String _owner = "patrickpatrick27";
  static const String _repo = "nap_locator";
  
  // Keep your token here
  static const String _token = "YOUR_GITHUB_TOKEN_HERE"; 

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
        String latestVersion = tagName.replaceAll('v', '');

        // FIND THE APK URL
        // GitHub releases have a list of 'assets'. We need the one ending in .apk
        String? apkUrl;
        List<dynamic> assets = data['assets'];
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.apk')) {
            apkUrl = asset['browser_download_url']; // This is the direct download link
            break;
          }
        }

        if (_isNewer(latestVersion, currentVersion) && apkUrl != null) {
          _showUpdateDialog(context, latestVersion, apkUrl);
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

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _status = "Downloading...";
    });

    try {
      // THIS IS THE MAGIC LINE
      OtaUpdate()
          .execute(widget.apkUrl, destinationFilename: 'nap_finder_update.apk')
          .listen(
        (OtaEvent event) {
          setState(() {
             // UPDATE STATUS
             if (event.status == OtaStatus.DOWNLOADING) {
               _progress = (int.parse(event.value ?? '0')) / 100;
               _status = "Downloading: ${event.value}%";
             } else if (event.status == OtaStatus.INSTALLING) {
               _status = "Installing...";
               _progress = 1.0; // 100%
             } else {
               _status = event.status.toString();
             }
          });
          
          // Note: When status is INSTALLING, the system install screen opens automatically.
        },
      ).onError((error) {
        setState(() {
          _status = "Error: $error";
          _isDownloading = false;
        });
      });
    } catch (e) {
      setState(() {
        _status = "Failed to start: $e";
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
          Text("A new version is available. Click update to download and install automatically."),
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