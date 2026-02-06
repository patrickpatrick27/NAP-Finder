import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED for admin check
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import '../widgets/detailed_sheet.dart';

class MapTab extends StatefulWidget {
  final CacheStore cacheStore;
  final List<dynamic> allLcps;
  final bool isLoading;
  final LatLng? currentLocation;
  final double currentHeading;
  final VoidCallback onRefresh;

  const MapTab({
    super.key,
    required this.cacheStore,
    required this.allLcps,
    required this.isLoading,
    required this.currentLocation,
    required this.currentHeading,
    required this.onRefresh,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<dynamic> _filteredLcps = [];
  List<Marker> _markers = [];
  bool _isSearching = false;
  bool _isFollowingUser = false;
  final LatLng _initialCenter = const LatLng(14.1153, 120.9621);

  @override
  void initState() {
    super.initState();
    if (widget.allLcps.isNotEmpty) {
      _generateOverviewMarkers(widget.allLcps);
    }
  }

  @override
  void didUpdateWidget(MapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allLcps != oldWidget.allLcps) {
      _generateOverviewMarkers(widget.allLcps);
    }
    if (_isFollowingUser && widget.currentLocation != null) {
      _mapController.move(widget.currentLocation!, 17.0);
    }
  }

  void _recenterOnUser() {
    if (widget.currentLocation != null) {
      setState(() => _isFollowingUser = true);
      _mapController.move(widget.currentLocation!, 17.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Waiting for GPS signal..."), duration: Duration(seconds: 1)),
      );
    }
  }

  Color _getOltColor(int? oltId) {
    switch (oltId) {
      case 1: return Colors.blue.shade700;
      case 2: return Colors.orange.shade800;
      case 3: return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }

  void _generateOverviewMarkers(List<dynamic> lcps) {
    List<Marker> markers = [];
    for (var lcp in lcps) {
      if (lcp['nps'] != null && lcp['nps'].isNotEmpty) {
        var firstNp = lcp['nps'][0];
        Color markerColor = _getOltColor(lcp['olt_id']);
        markers.add(
          Marker(
            point: LatLng(firstNp['lat'], firstNp['lng']),
            width: 45,
            height: 45,
            child: GestureDetector(
              onTap: () => _focusOnLcp(lcp),
              child: Icon(Icons.location_on, color: markerColor, size: 45),
            ),
          ),
        );
      }
    }
    setState(() => _markers = markers);
  }

  void _focusOnLcp(dynamic lcp) {
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _isFollowingUser = false;
    });

    List<Marker> npMarkers = [];
    List<LatLng> points = [];
    Color oltColor = _getOltColor(lcp['olt_id']);

    // Check Login Status Here
    bool isAdmin = FirebaseAuth.instance.currentUser != null;

    for (var np in lcp['nps']) {
      LatLng pos = LatLng(np['lat'], np['lng']);
      points.add(pos);
      npMarkers.add(
        Marker(
          point: pos,
          width: 80,
          height: 60,
          child: GestureDetector(
            onTap: () => DetailedSheet.show(context, lcp, isAdmin: isAdmin),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Text(np['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Icon(Icons.radio_button_checked, color: oltColor, size: 30),
              ],
            ),
          ),
        ),
      );
    }

    setState(() => _markers = npMarkers);
    
    if (points.isNotEmpty) {
       double minLat = points.first.latitude;
       double maxLat = points.first.latitude;
       double minLng = points.first.longitude;
       double maxLng = points.first.longitude;

       for (var p in points) {
         if (p.latitude < minLat) minLat = p.latitude;
         if (p.latitude > maxLat) maxLat = p.latitude;
         if (p.longitude < minLng) minLng = p.longitude;
         if (p.longitude > maxLng) maxLng = p.longitude;
       }
       
       if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
          _mapController.move(LatLng(minLat, minLng), 18.0);
       } else {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
              padding: const EdgeInsets.all(80),
            ),
          );
       }
    }
    // Check again and pass to initial sheet
    DetailedSheet.show(context, lcp, isAdmin: isAdmin);
  }

  void _resetMap() {
    _searchController.clear();
    _generateOverviewMarkers(widget.allLcps);
    _mapController.move(_initialCenter, 13.0);
    setState(() {
      _isSearching = false;
      _isFollowingUser = false;
    });
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _generateOverviewMarkers(widget.allLcps);
      setState(() => _isSearching = false);
      return;
    }
    setState(() => _isSearching = true);

    final filtered = widget.allLcps.where((lcp) {
      final name = lcp['lcp_name'].toString().toLowerCase();
      final site = lcp['site_name'].toString().toLowerCase();
      final olt = "olt ${lcp['olt_id']}";
      return name.contains(query.toLowerCase()) || 
             site.contains(query.toLowerCase()) || 
             olt.contains(query.toLowerCase());
    }).toList();

    setState(() => _filteredLcps = filtered);
    _generateOverviewMarkers(filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, __) => _searchFocusNode.unfocus(),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _isFollowingUser = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.davepatrick.napboxlocator',
                tileProvider: CachedTileProvider(
                  store: widget.cacheStore, 
                  maxStale: const Duration(days: 365), 
                ),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15, 
                  markers: _markers,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.blueGrey, 
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.currentLocation!,
                      width: 50,
                      height: 50,
                      child: Transform.rotate(
                        angle: (widget.currentHeading * (math.pi / 180)),
                        child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Search Bar
          Positioned(
            top: 50, left: 15, right: 15,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Search LCP, Site, or 'OLT 1'...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: widget.isLoading 
                        ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 3))
                        : IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.blue),
                                onPressed: widget.onRefresh,
                          ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    onChanged: _onSearchChanged,
                    onTap: () {
                      if (_searchController.text.isNotEmpty) setState(() => _isSearching = true);
                    },
                  ),
                ),
                if (_isSearching && _filteredLcps.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    height: 250, 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _filteredLcps.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var lcp = _filteredLcps[index];
                        return ListTile(
                          title: Text(lcp['lcp_name']),
                          subtitle: Text(lcp['site_name']),
                          trailing: Text("OLT ${lcp['olt_id']}"),
                          onTap: () => _focusOnLcp(lcp),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          Positioned(
            top: 130, right: 15,
            child: FloatingActionButton.small(
              heroTag: "gps",
              backgroundColor: _isFollowingUser ? Colors.blue : Colors.white, 
              onPressed: _recenterOnUser,
              child: Icon(Icons.my_location, color: _isFollowingUser ? Colors.white : Colors.black87),
            ),
          ),
          
          Positioned(
            bottom: 20, right: 20,
            child: FloatingActionButton.small(
              heroTag: "reset",
              onPressed: _resetMap,
              child: const Icon(Icons.map),
            ),
          ),
        ],
      ),
    );
  }
}