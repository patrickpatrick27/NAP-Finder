import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for Auth
  await Firebase.initializeApp();

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
      home: AuthWrapper(cacheStore: cacheStore),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final CacheStore cacheStore;
  final AuthService _authService = AuthService();

  AuthWrapper({super.key, required this.cacheStore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.userStream,
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Logged In State
        if (snapshot.hasData && snapshot.data != null) {
          return MainScreen(cacheStore: cacheStore);
        }

        // 3. Logged Out State
        return const LoginScreen();
      },
    );
  }
}