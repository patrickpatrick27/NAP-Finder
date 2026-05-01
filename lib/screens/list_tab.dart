import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/detailed_sheet.dart';

class ListTab extends StatefulWidget {
  final List<dynamic> allLcps;
  final bool isLoading;
  final VoidCallback onRefresh;
  final String userRole;

  const ListTab({
    super.key,
    required this.allLcps,
    required this.isLoading,
    required this.onRefresh,
    required this.userRole,
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
        content: Text("Logged in as ${FirebaseAuth.instance.currentUser?.email}.\n\nAccess Level: ${widget.userRole.toUpperCase()}"),
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

  // --- REVISED FLATTENING LOGIC (For 60FPS Performance) ---
  List<dynamic> _getFlattenedList() {
    // 1. Filter raw data
    List<dynamic> filtered = widget.allLcps;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = widget.allLcps.where((lcp) {
        return lcp['lcp_name'].toString().toLowerCase().contains(q) ||
               lcp['site_name'].toString().toLowerCase().contains(q) ||
               "olt ${lcp['olt_id']}".toLowerCase().contains(q);
      }).toList();
    }

    // 2. Group by Site
    Map<String, List<dynamic>> grouped = {};
    for (var lcp in filtered) {
      String site = (lcp['site_name'] ?? 'Unknown Site').toString();
      if (!grouped.containsKey(site)) grouped[site] = [];
      grouped[site]!.add(lcp);
    }

    // 3. Flatten into a single list of Header/NAP items
    List<dynamic> flatList = [];
    List<String> sortedSites = grouped.keys.toList()..sort();
    
    for (String site in sortedSites) {
      // Add a Header Object
      flatList.add({'isHeader': true, 'title': site, 'count': grouped[site]!.length});
      // Add all NAP Objects for this site
      flatList.addAll(grouped[site]!);
    }
    
    return flatList;
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
    final flatItems = _getFlattenedList();
    final isAdmin = widget.userRole == 'admin';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isAdmin ? Colors.red.shade50 : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Site Directory", 
              style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(widget.userRole.toUpperCase(), style: TextStyle(color: isAdmin ? Colors.red : Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(onPressed: widget.onRefresh, icon: const Icon(Icons.sync, color: Colors.blueGrey)),
          IconButton(onPressed: _showLogoutDialog, icon: Icon(Icons.account_circle, color: isAdmin ? Colors.redAccent : Colors.blueGrey)),
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
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: widget.isLoading && widget.allLcps.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : flatItems.isEmpty
          ? const Center(child: Text("No results found"))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: flatItems.length,
              itemBuilder: (context, index) {
                final item = flatItems[index];

                if (item is Map && item.containsKey('isHeader')) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 25, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          item['title'].toString().toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[900], letterSpacing: 1.2),
                        ),
                        const Spacer(),
                        Text("${item['count']} NAPs", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                final lcp = item;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      dense: true,
                      onTap: () => DetailedSheet.show(context, lcp, isAdmin: isAdmin),
                      leading: Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getOltColor(lcp['olt_id']),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      title: Text(lcp['lcp_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(
                        "OLT ${lcp['olt_id']} • ${lcp['details']?['Distance'] ?? '-'}",
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
