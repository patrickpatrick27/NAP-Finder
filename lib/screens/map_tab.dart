import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _MapTabState extends State<MapTab> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<dynamic> _filteredLcps = [];
  List<Marker> _markers = [];
  bool _isSearching = false;
  bool _isFollowingUser = false;
  bool _isViewingSpecificLcp = false;

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
    if (_isFollowingUser && widget.currentLocation != null && widget.currentLocation != oldWidget.currentLocation) {
      _animatedMapMove(widget.currentLocation!, 17.0, fast: true);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom, {bool fast = false}) {
    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: Duration(milliseconds: fast ? 300 : 800), vsync: this);
    
    final Animation<double> animation = CurvedAnimation(
        parent: controller, 
        curve: fast ? Curves.easeOut : Curves.easeInOutQuart);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _recenterOnUser() {
    if (widget.currentLocation != null) {
      setState(() => _isFollowingUser = true);
      _animatedMapMove(widget.currentLocation!, 17.0, fast: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Searching for GPS..."), duration: Duration(seconds: 1)),
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
    setState(() {
       _markers = markers;
       _isViewingSpecificLcp = false;
    });
  }

  void _focusOnLcp(dynamic lcp) {
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _isFollowingUser = false;
      _isViewingSpecificLcp = true;
    });

    List<Marker> npMarkers = [];
    List<LatLng> points = [];
    Color oltColor = _getOltColor(lcp['olt_id']);
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
       _animatedMapMove(points.first, 18.0);
    }
    DetailedSheet.show(context, lcp, isAdmin: isAdmin);
  }

  /// IMPROVED RESET LOGIC: Calculates the exact center of all NAPs
  void _resetMap() {
    _searchController.clear();
    _generateOverviewMarkers(widget.allLcps);
    
    if (widget.allLcps.isNotEmpty) {
      List<LatLng> allPoints = [];
      for (var lcp in widget.allLcps) {
        if (lcp['nps'] != null) {
          for (var np in lcp['nps']) {
            allPoints.add(LatLng(np['lat'], np['lng']));
          }
        }
      }

      if (allPoints.isNotEmpty) {
        // Calculate the center (mean) of every single NAP coordinate
        double avgLat = 0;
        double avgLng = 0;
        for (var p in allPoints) {
          avgLat += p.latitude;
          avgLng += p.longitude;
        }
        LatLng centerOfNaps = LatLng(avgLat / allPoints.length, avgLng / allPoints.length);

        // Move to that center smoothly. Zoom level 13.5 provides a good balance.
        _animatedMapMove(centerOfNaps, 13.5);
      }
    }
    
    setState(() {
      _isSearching = false;
      _isFollowingUser = false;
      _isViewingSpecificLcp = false;
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
              initialCenter: const LatLng(14.1153, 120.9621),
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
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
                tileDisplay: const TileDisplay.fadeIn(
                  duration: Duration(milliseconds: 400),
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

          // --- Search Bar ---
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
          
          // --- SLEEK MY LOCATION BUTTON ---
          Positioned(
            bottom: 20, right: 20,
            child: SizedBox(
              height: 32, 
              child: FloatingActionButton.extended(
                heroTag: "gps",
                onPressed: _recenterOnUser,
                elevation: 2,
                backgroundColor: _isFollowingUser ? Colors.blue : Colors.white,
                extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
                icon: Icon(Icons.my_location, size: 14, color: _isFollowingUser ? Colors.white : Colors.black87),
                label: Text(
                  "My Location",
                  style: TextStyle(fontSize: 10, color: _isFollowingUser ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ),
          
          // --- SLEEK RESET / RETURN BUTTON ---
          Positioned(
            bottom: 20, left: 20,
            child: SizedBox(
              height: 32, 
              child: FloatingActionButton.extended(
                heroTag: "reset",
                onPressed: _resetMap,
                elevation: 2,
                backgroundColor: Colors.white,
                extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
                icon: const Icon(Icons.map, size: 14, color: Colors.black87),
                label: Text(
                  _isViewingSpecificLcp ? "Return" : "Reset",
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}