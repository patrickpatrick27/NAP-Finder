import 'package:flutter_test/flutter_test.dart';
import 'package:napfinder/services/sheet_service.dart'; // Update path if needed

void main() {
  group('SheetParser Logic', () {
    // 1. Create a fake "Google Sheet" row structure
    // Row 1: Headers (mocking the OLT PORT columns)
    // Row 2: Data (A valid LCP and a Vacant one)
    final mockRawRows = [
      // Row 0: Irrelevant title row
      ["Title", "Date"], 
      // Row 1: Headers - Note indices: 0 is OLT PORT
      ["OLT PORT", "LCP Name", "Site", "ODF", "Port", "Date", "Dist", "Rack", "New ODF", "New Port", "NP1-2", "NP3-4", "NP5-6", "NP7-8"],
      // Row 2: The Data
      [
        "1", "LCP-TEST-01", "Cavite Site", "ODF-A", "1", "2024", "100m", "R1", "NO", "NP", 
        "14.1234, 120.9876", // NP1-2 (Valid)
        "N/A",               // NP3-4 (Invalid)
        "",                  // NP5-6 (Empty)
        "14.5555, 121.5555"  // NP7-8 (Valid)
      ],
      // Row 3: A VACANT row (Should be ignored)
      ["2", "VACANT", "Manila Site", "", "", "", "", "", "", "", "", "", "", ""]
    ];

    test('correctly parses valid LCP rows', () {
      final service = SheetService();
      
      // Call the function (Make sure you removed the '_' from parseSheetData)
      final results = service.parseSheetData(mockRawRows, 'TestSheet');

      expect(results.length, 1, reason: "Should ignore the VACANT row and keep the valid one");
      
      final lcp = results.first;
      expect(lcp['lcp_name'], 'LCP-TEST-01');
      expect(lcp['site_name'], 'Cavite Site');
      expect(lcp['olt_id'], 1); // Derived from block index logic
    });

    test('correctly extracts valid coordinates', () {
      final service = SheetService();
      final results = service.parseSheetData(mockRawRows, 'TestSheet');
      final lcp = results.first;
      
      final nps = lcp['nps'] as List;
      
      // We expect 2 valid NPs (NP1-2 and NP7-8) out of 4 columns
      expect(nps.length, 2);
      
      expect(nps[0]['name'], 'NP1-2');
      expect(nps[0]['lat'], 14.1234);
      expect(nps[0]['lng'], 120.9876);
      
      expect(nps[1]['name'], 'NP7-8');
      expect(nps[1]['lat'], 14.5555);
    });
  });
}