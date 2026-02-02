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
  Map<String, Map<String, List<dynamic>>> _getGroupedData() {
    Map<String, Map<String, List<dynamic>>> grouped = {};

    for (var lcp in widget.allLcps) {
      String sheetName = lcp['source_sheet'] ?? 'Unknown Sheet';
      String siteName = lcp['site_name'] ?? 'Unknown Site';

      if (!grouped.containsKey(sheetName)) {
        grouped[sheetName] = {};
      }
      if (!grouped[sheetName]!.containsKey(siteName)) {
        grouped[sheetName]![siteName] = [];
      }
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
    
    // Calculate Grand Total
    int totalNaps = widget.allLcps.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // Setting white background so black text is visible
        elevation: 1,
        centerTitle: true, // Forces it to the middle
        title: Text(
          "Total NAPs: $totalNaps", 
          style: const TextStyle(
            color: Colors.black, 
            fontSize: 22, // Bigger font
            fontWeight: FontWeight.bold
          )
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
              icon: const Icon(Icons.refresh, color: Colors.black) // Icon also black to match
            )
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
              title: Text(
                sheetName, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)
              ),
              subtitle: Text(
                "$totalBoxesInSheet NAPs in ${sortedSites.length} Locations",
                style: TextStyle(color: Colors.grey[600], fontSize: 12)
              ),
              childrenPadding: const EdgeInsets.only(left: 10, bottom: 10, right: 10),
              children: sortedSites.map((siteName) {
                List<dynamic> lcps = sitesInSheet[siteName]!;
                
                return Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300)
                  ),
                  child: ExpansionTile(
                    title: Text(
                      siteName, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)
                    ),
                    subtitle: Text("${lcps.length} items"),
                    leading: const Icon(Icons.place, color: Colors.blueGrey, size: 20),
                    children: lcps.map((lcp) {
                      Color oltColor = _getOltColor(lcp['olt_id']);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 20, right: 10),
                        leading: Icon(Icons.router, color: oltColor, size: 18),
                        title: Text(
                          lcp['lcp_name'], 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(
                          "OLT ${lcp['olt_id']} • ${lcp['details']?['Distance'] ?? ''}",
                          style: TextStyle(fontSize: 11, color: Colors.grey[700])
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
                        onTap: () {
                           DetailedSheet.show(context, lcp);
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