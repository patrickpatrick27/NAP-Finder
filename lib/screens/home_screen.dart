import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:restart_app/restart_app.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import '../services/sheet_service.dart';
import '../services/update_service.dart';
import 'map_tab.dart';
import 'list_tab.dart';

class MainScreen extends StatefulWidget {
  final CacheStore cacheStore;
  const MainScreen({super.key, required this.cacheStore});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _updater = ShorebirdUpdater();
  
  List<dynamic> _allLcps = [];
  bool _isLoading = true;

  LatLng? _currentLocation;
  double _currentHeading = 0.0;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLiveLocationUpdates();
    _checkForShorebirdUpdate();
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) GithubUpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    List<dynamic> cached = await SheetService().loadFromCache();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _allLcps = cached;
      });
    }

    List<dynamic> freshData = await SheetService().fetchLcpData();
    
    if (mounted) {
      setState(() {
        if (freshData.isNotEmpty) {
          _allLcps = freshData;
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Sync Complete: ${_allLcps.length} NAPs loaded"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkForShorebirdUpdate() async {
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _updater.update();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Patch Ready 🚀"),
              content: const Text("Update downloaded. Restart now?"),
              actions: [
                TextButton(
                  onPressed: () => Restart.restartApp(),
                  child: const Text("Restart Now"),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _startLiveLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null && mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      },
    );

    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        setState(() {
          _currentHeading = event.heading!;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MapTab(
            cacheStore: widget.cacheStore,
            allLcps: _allLcps,
            isLoading: _isLoading,
            currentLocation: _currentLocation,
            currentHeading: _currentHeading,
            onRefresh: _loadData,
          ),
          ListTab(
            allLcps: _allLcps,
            isLoading: _isLoading,
            onRefresh: _loadData,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Sites List',
          ),
        ],
      ),
    );
  }
}