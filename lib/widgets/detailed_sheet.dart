import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailedSheet {
  static void show(BuildContext context, dynamic lcp) {
    Color themeColor = _getOltColor(lcp['olt_id']);
    Map<String, dynamic> details = lcp['details'] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(child: Container(width: 40, height: 4, color: Colors.grey[300])),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(lcp['lcp_name'], 
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text("OLT ${lcp['olt_id']}", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(lcp['site_name'], style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const Divider(height: 30),
                  _buildSectionTitle("Patching Details", themeColor),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildDetailCard(context, "OLT Port", details['OLT Port']), 
                      _buildDetailCard(context, "ODF", details['ODF']),
                      _buildDetailCard(context, "ODF Port", details['ODF Port']),
                      _buildDetailCard(context, "New ODF", details['New ODF']),
                      _buildDetailCard(context, "New Port", details['New Port']),
                      _buildDetailCard(context, "Rack ID", details['Rack ID']),
                      _buildDetailCard(context, "Date/NMP", details['Date'], isWide: true),
                      _buildDetailCard(context, "Distance", details['Distance']),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Coordinates & Navigation", themeColor),
                  ...lcp['nps'].map<Widget>((np) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: themeColor.withOpacity(0.1),
                        child: Icon(Icons.location_on, color: themeColor, size: 20),
                      ),
                      title: Text(np['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${np['lat']}, ${np['lng']}", style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                            tooltip: "Copy Coordinates",
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: "${np['lat']}, ${np['lng']}"));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Coordinates copied! 📋"), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.directions, size: 24, color: Colors.blue),
                            tooltip: "Get Directions",
                            onPressed: () => _launchMaps(np['lat'], np['lng']),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _launchMaps(double lat, double lng) async {
    final Uri googleUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (!await launchUrl(googleUrl, mode: LaunchMode.externalApplication)) {
         throw 'Could not launch Maps';
      }
    } catch (e) {
      print("Error launching map: $e");
    }
  }

  static Color _getOltColor(int? oltId) {
    switch (oltId) {
      case 1: return Colors.blue.shade700;
      case 2: return Colors.orange.shade800;
      case 3: return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }

  static Widget _buildSectionTitle(String title, Color color) {
    return Row(children: [
      Icon(Icons.info, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  static Widget _buildDetailCard(BuildContext context, String label, String? value, {bool isWide = false}) {
    String displayValue = (value == null || value.isEmpty) ? "-" : value;
    return Material( 
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: displayValue));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$label copied! 📋"), 
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: isWide ? double.infinity : 100, 
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(displayValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}