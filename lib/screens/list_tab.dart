import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/detailed_sheet.dart';

class ListTab extends StatefulWidget {
  final List<dynamic> allLcps;
  final bool isLoading;
  final VoidCallback onRefresh;

  const ListTab({
    super.key,
    required this.allLcps,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  // Track Admin Status
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// ---------------------------------------------------
  /// THE BOUNCER LOGIC
  /// ---------------------------------------------------
  Future<void> _checkLoginStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // 1. If not logged in, just reset state and wait.
    if (user == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }

    try {
      // 2. CHECK THE GUEST LIST (Firestore)
      final docSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.email) 
          .get();

      if (docSnapshot.exists) {
        // --- SUCCESS ---
        print("✅ Admin verified: ${user.email}");
        if (mounted) setState(() => _isAdmin = true);
      } else {
        // --- FAIL ---
        print("⛔ Unauthorized user: ${user.email}. Kicking out...");
        await _forceLogout(); 
        
        if (mounted) {
          _showErrorDialog(
            "Access Denied", 
            "The account '${user.email}' is not on the admin list."
          );
        }
      }
    } catch (e) {
      print("Error verifying admin: $e");
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  Future<void> _forceLogout() async {
    final googleSignIn = GoogleSignIn();
    try { await googleSignIn.disconnect(); } catch (_) {}
    await googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() => _isAdmin = false);
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      try { await googleSignIn.disconnect(); } catch (_) {} 

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _checkLoginStatus();

      if (mounted && _isAdmin) Navigator.pop(context); 

    } catch (e) {
      if (mounted) _showErrorDialog("Login Error", e.toString());
    }
  }

  // --- UI HELPERS ---
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18)),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isAdmin ? "Admin Options" : "Admin Access"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAdmin)
               Text("Logged in as ${FirebaseAuth.instance.currentUser?.email}.\n\nAdministrative access granted.")
            else
               const Text("Technicians have restricted view access.\n\nSign in with an authorized Google account to view full system details."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (_isAdmin)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await _forceLogout();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Log Out"),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text("Sign in with Google"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              onPressed: _handleGoogleSignIn,
            ),
        ],
      ),
    );
  }

  Map<String, Map<String, List<dynamic>>> _getGroupedData() {
    Map<String, Map<String, List<dynamic>>> grouped = {};
    for (var lcp in widget.allLcps) {
      String sheetName = (lcp['source_sheet'] ?? 'Unknown Sheet').toString();
      String siteName = (lcp['site_name'] ?? 'Unknown Site').toString();

      if (!grouped.containsKey(sheetName)) grouped[sheetName] = {};
      if (!grouped[sheetName]!.containsKey(siteName)) grouped[sheetName]![siteName] = [];
      grouped[sheetName]![siteName]!.add(lcp);
    }
    return grouped;
  }

  Color _getOltColor(int oltId) {
    switch (oltId) {
      case 1: return Colors.blue.shade700;
      case 2: return Colors.orange.shade800;
      case 3: return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.allLcps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.allLcps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.grey),
            const SizedBox(height: 10),
            const Text("No data found"),
            TextButton(onPressed: widget.onRefresh, child: const Text("Retry"))
          ],
        ),
      );
    }

    final groupedData = _getGroupedData();
    final sortedSheets = groupedData.keys.toList()..sort();
    int totalNaps = widget.allLcps.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isAdmin ? Colors.red.shade50 : Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Column(
          children: [
            Text("Total NAPs: $totalNaps", 
              style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
            if (_isAdmin) 
              const Text("ADMIN MODE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          widget.isLoading 
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 18, 
                height: 18, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueGrey),
              ),
            )
          : IconButton(
              onPressed: widget.onRefresh, 
              icon: const Icon(Icons.refresh, color: Colors.black)
            ),
          IconButton(
            onPressed: _showAdminDialog,
            icon: Icon(
              _isAdmin ? Icons.lock_open : Icons.lock, 
              color: _isAdmin ? Colors.red : Colors.grey
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 10),
        itemCount: sortedSheets.length,
        itemBuilder: (context, index) {
          String sheetName = sortedSheets[index];
          Map<String, List<dynamic>> sitesInSheet = groupedData[sheetName]!;
          List<String> sortedSites = sitesInSheet.keys.toList()..sort();
          int totalBoxesInSheet = sitesInSheet.values.fold(0, (sum, list) => sum + list.length);

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey.shade800,
                foregroundColor: Colors.white,
                radius: 18,
                child: Text(sheetName.substring(0, 1)),
              ),
              title: Text(sheetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
              subtitle: Text("$totalBoxesInSheet NAPs in ${sortedSites.length} Locations", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              childrenPadding: const EdgeInsets.only(left: 10, bottom: 10, right: 10),
              children: sortedSites.map((siteName) {
                List<dynamic> lcps = sitesInSheet[siteName]!;
                return Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(siteName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text("${lcps.length} items"),
                    leading: const Icon(Icons.place, color: Colors.blueGrey, size: 20),
                    children: lcps.map((lcp) {
                      Color oltColor = _getOltColor(lcp['olt_id']);
                      String subtitleText = "OLT ${lcp['olt_id']} • ${lcp['details']?['Distance'] ?? ''}";
                      
                      // Removed "Status" from subtitleText to match request to remove status/notes
                      // subtitleText += "\nStatus: ${lcp['details']?['Status'] ?? 'Active'}"; 

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 20, right: 10),
                        leading: Icon(Icons.router, color: oltColor, size: 18),
                        title: Text(lcp['lcp_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitleText, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
                        onTap: () {
                           // PASS ADMIN STATUS
                           DetailedSheet.show(context, lcp, isAdmin: _isAdmin);
                        },
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}