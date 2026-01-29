import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/home_screen.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dir = await getApplicationDocumentsDirectory();
  final cachePath = '${dir.path}/map_tiles';
  final cacheStore = FileCacheStore(cachePath);

  runApp(MyApp(cacheStore: cacheStore));
}

class MyApp extends StatelessWidget {
  final CacheStore cacheStore;

  const MyApp({super.key, required this.cacheStore});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NAP Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainScreen(cacheStore: cacheStore),
    );
  }
}