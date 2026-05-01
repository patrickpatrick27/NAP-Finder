import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
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
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin Options"),
        content: Text("Logged in as ${FirebaseAuth.instance.currentUser?.email}.\n\nAdministrative access granted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }

  // --- FILTERING LOGIC ---
  List<dynamic> _getFilteredData() {
    if (_searchQuery.isEmpty) return widget.allLcps;
    
    return widget.allLcps.where((lcp) {
      final name = lcp['lcp_name'].toString().toLowerCase();
      final site = lcp['site_name'].toString().toLowerCase();
      final olt = "olt ${lcp['olt_id']}".toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || site.contains(query) || olt.contains(query);
    }).toList();
  }

  // --- GROUPING LOGIC ---
  Map<String, List<dynamic>> _groupData(List<dynamic> data) {
    Map<String, List<dynamic>> grouped = {};
    for (var lcp in data) {
      String siteName = (lcp['site_name'] ?? 'Unknown Site').toString();
      if (!grouped.containsKey(siteName)) grouped[siteName] = [];
      grouped[siteName]!.add(lcp);
    }
    return grouped;
  }

  Color _getOltColor(int? oltId) {
    switch (oltId) {
      case 1: return Colors.blue.shade700;
      case 2: return Colors.orange.shade800;
      case 3: return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredData();
    final grouped = _groupData(filtered);
    final sortedSites = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text("Site Directory", 
          style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: widget.onRefresh, 
            icon: const Icon(Icons.sync, color: Colors.blueGrey)
          ),
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.account_circle, color: Colors.redAccent),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search NAP, Site, or OLT...",
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    })
                  : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: widget.isLoading && widget.allLcps.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No results for '$_searchQuery'", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: sortedSites.length,
              itemBuilder: (context, index) {
                final siteName = sortedSites[index];
                final lcps = grouped[siteName]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Site Header ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            siteName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text("${lcps.length} NAPs", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    // --- NAP List for this site ---
                    ...lcps.map((lcp) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          onTap: () => DetailedSheet.show(context, lcp, isAdmin: true),
                          leading: Container(
                            width: 4,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _getOltColor(lcp['olt_id']),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(
                            lcp['lcp_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            "OLT ${lcp['olt_id']} • ${lcp['details']?['Distance'] ?? 'Unknown Dist.'}",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        ),
                      ),
                    )).toList(),
                  ],
                );
              },
            ),
    );
  }
}
