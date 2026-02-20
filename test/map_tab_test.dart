import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:mocktail/mocktail.dart';
import 'package:napfinder/screens/map_tab.dart';

// --- 1. MOCKS ---
class MockHttpClient extends Mock implements HttpClient {}
class MockHttpClientRequest extends Mock implements HttpClientRequest {}

// --- 2. ROBUST FAKES (The Silence Makers) ---

class FakeHttpClientResponse extends Fake implements HttpClientResponse, Stream<List<int>> {
  final Stream<List<int>> _stream = const Stream<List<int>>.empty();

  @override
  int get statusCode => 404;

  @override
  int get contentLength => 0;

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  // --- FIXES FOR DIO ERRORS ---
  @override
  bool get isRedirect => false; // <--- Fixes "UnimplementedError: isRedirect"

  @override
  String get reasonPhrase => "Not Found"; // Good practice to have

  @override
  List<RedirectInfo> get redirects => []; // Fixes potential redirect loop checks

  // --- STREAM HANDLING ---
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Stream<R> cast<R>() => _stream.cast<R>();
}

class FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  void removeAll(String name) => _headers.remove(name);

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  String? value(String name) {
    final values = _headers[name];
    return (values != null && values.isNotEmpty) ? values.first : null;
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }
}

// --- 3. HTTP OVERRIDES ---
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = MockHttpClient();
    final request = MockHttpClientRequest();
    final response = FakeHttpClientResponse();
    final headers = FakeHttpHeaders();

    when(() => client.getUrl(any())).thenAnswer((_) async => request);
    when(() => client.openUrl(any(), any())).thenAnswer((_) async => request);
    when(() => request.headers).thenReturn(headers);
    when(() => request.close()).thenAnswer((_) async => response);

    return client;
  }
}

// --- 4. TESTS ---
void main() {
  late CacheStore memCacheStore;

  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
    registerFallbackValue(Uri());
  });

  setUp(() {
    memCacheStore = MemCacheStore();
  });

  final mockLcps = [
    {
      'lcp_name': 'LCP-001',
      'site_name': 'Test Site',
      'olt_id': 1,
      'nps': [
        {'name': 'NP1', 'lat': 14.0, 'lng': 121.0}
      ]
    },
    {
      'lcp_name': 'LCP-002',
      'site_name': 'Another Site',
      'olt_id': 2,
      'nps': []
    }
  ];

  testWidgets('MapTab renders buttons and search bar', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapTab(
          cacheStore: memCacheStore,
          allLcps: mockLcps,
          isLoading: false,
          currentLocation: const LatLng(14.0, 121.0),
          currentHeading: 0,
          onRefresh: () {},
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text("My Location"), findsOneWidget);
    expect(find.text("Reset"), findsOneWidget);
  });

  testWidgets('Search bar filters results', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapTab(
          cacheStore: memCacheStore,
          allLcps: mockLcps,
          isLoading: false,
          currentLocation: null,
          currentHeading: 0,
          onRefresh: () {},
        ),
      ),
    ));
    
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'LCP-001');
    await tester.pump(); 
    await tester.pump(const Duration(milliseconds: 500)); 

    expect(find.widgetWithText(ListTile, 'LCP-001'), findsOneWidget);
    expect(find.text('LCP-002'), findsNothing);
    
    await tester.pumpAndSettle();
  });
}