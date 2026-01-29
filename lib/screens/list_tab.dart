import 'package:flutter/material.dart';
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
  Map<String, Map<int, List<dynamic>>> _getGroupedData() {
    Map<String, Map<int, List<dynamic>>> grouped = {};

    for (var lcp in widget.allLcps) {
      String siteName = lcp['site_name'] ?? 'Unknown Site';
      int oltId = lcp['olt_id'] ?? 0;

      if (!grouped.containsKey(siteName)) {
        grouped[siteName] = {};
      }
      if (!grouped[siteName]!.containsKey(oltId)) {
        grouped[siteName]![oltId] = [];
      }
      grouped[siteName]![oltId]!.add(lcp);
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
    final sortedSites = groupedData.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text("All NAP Boxes"),
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
          : IconButton(onPressed: widget.onRefresh, icon: const Icon(Icons.refresh))
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 10),
        itemCount: sortedSites.length,
        itemBuilder: (context, index) {
          String siteName = sortedSites[index];
          Map<int, List<dynamic>> oltsInSite = groupedData[siteName]!;
          List<int> sortedOlts = oltsInSite.keys.toList()..sort();

          int totalBoxes = oltsInSite.values.fold(0, (sum, list) => sum + list.length);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment, color: Colors.blueGrey),
              ),
              title: Text(
                siteName, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              subtitle: Text(
                "$totalBoxes Boxes across ${sortedOlts.length} OLTs",
                style: TextStyle(color: Colors.grey[600], fontSize: 12)
              ),
              childrenPadding: const EdgeInsets.only(left: 10, bottom: 10),
              children: sortedOlts.map((oltId) {
                Color oltColor = _getOltColor(oltId);
                List<dynamic> lcps = oltsInSite[oltId]!;
                
                return ExpansionTile(
                  leading: Icon(Icons.router, color: oltColor),
                  title: Text(
                    "OLT $oltId", 
                    style: TextStyle(color: oltColor, fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text("${lcps.length} NAPs"),
                  children: lcps.map((lcp) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 20, right: 20),
                      leading: const Icon(Icons.location_on, size: 18),
                      title: Text(lcp['lcp_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lcp['details']?['Address'] ?? lcp['site_name']),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                         DetailedSheet.show(context, lcp);
                      },
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}