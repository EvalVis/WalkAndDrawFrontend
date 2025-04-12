import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk and Draw',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  bool _locationPermissionGranted = false;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  GenerativeModel? _model;
  bool _isLoading = false;

  final LatLng _center = const LatLng(-34.0, 151.0);

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {
    try {
      final apiKey =
          await const MethodChannel('com.example.walk_and_draw/config')
              .invokeMethod<String>('getGeminiApiKey');

      if (apiKey != null && apiKey.isNotEmpty) {
        _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        );
      }
    } catch (e) {
      print('Error initializing Gemini: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    setState(() {
      _locationPermissionGranted = true;
    });

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _updateCurrentLocationMarker();
    } catch (e) {
      // Ignore position error as the app can still work with default location
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: const InfoWindow(
            title: 'Current Location',
            snippet: 'You are here',
          ),
        ),
      };
    });
  }

  Future<void> _requestDrawingSuggestion() async {
    if (_model == null || _currentPosition == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prompt =
          '''Starting from my current location at (${_currentPosition!.latitude}, ${_currentPosition!.longitude}), provide coordinates for a simple drawing on a map. Requirements:
1. First coordinate MUST be (${_currentPosition!.latitude}, ${_currentPosition!.longitude})
2. Total walking distance must not exceed 10 kilometers
3. Return ONLY a JSON array in this exact format, with no other text: [{"lat": x1, "lng": y1}, {"lat": x2, "lng": y2}, ...]''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      if (response.text != null) {
        // TODO: Parse the JSON response and create polylines
        // For now, let's create a sample heart shape
        _createSampleDrawing();
      }
    } catch (e) {
      print('Error getting drawing suggestion: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createSampleDrawing() {
    if (_currentPosition == null) return;

    // Create a heart shape around current location
    final center =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final scale = 0.001; // Adjust this to change the size of the drawing

    final points = <LatLng>[
      LatLng(center.latitude + scale, center.longitude),
      LatLng(center.latitude + scale / 2, center.longitude + scale / 2),
      LatLng(center.latitude, center.longitude + scale),
      LatLng(center.latitude - scale / 2, center.longitude + scale / 2),
      LatLng(center.latitude - scale, center.longitude),
      LatLng(center.latitude - scale / 2, center.longitude - scale / 2),
      LatLng(center.latitude, center.longitude - scale),
      LatLng(center.latitude + scale / 2, center.longitude - scale / 2),
      LatLng(center.latitude + scale, center.longitude),
    ];

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('drawing'),
          points: points,
          color: Colors.red,
          width: 3,
        ),
      );
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk and Draw'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.brush),
            tooltip: 'Suggest Drawing',
            onPressed: _requestDrawingSuggestion,
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition != null
              ? LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                )
              : _center,
          zoom: 15.0,
        ),
        myLocationEnabled: _locationPermissionGranted,
        myLocationButtonEnabled: _locationPermissionGranted,
        markers: _markers,
        polylines: _polylines,
      ),
    );
  }
}
