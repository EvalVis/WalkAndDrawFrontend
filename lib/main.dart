import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

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

  // Default center (will be updated when we get current location)
  final LatLng _defaultCenter = const LatLng(54.687157, 25.279652); // Vilnius coordinates

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
    
    final latLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: latLng,
          infoWindow: const InfoWindow(
            title: 'Current Location',
            snippet: 'You are here',
          ),
        ),
      };
    });

    // Move camera to current location
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 15.0,
        ),
      ),
    );
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
2. Total walking distance must not exceed 20 kilometers
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

    final random = math.Random();
    final numPoints =
        random.nextInt(81) + 20; // Random between 20 and 100 points
    final points = <LatLng>[];

    // Start from current location
    points.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));

    double totalDistance = 0;
    final maxDistance = 20000; // 20 kilometers in meters

    for (int i = 1; i < numPoints && totalDistance < maxDistance; i++) {
      final lastPoint = points.last;

      // Generate random angle and distance
      final angle = random.nextDouble() * 2 * math.pi;
      final maxStepDistance = (maxDistance - totalDistance) / (numPoints - i);
      final stepDistance = random.nextDouble() *
          math.min(300, maxStepDistance); // Max 300m per step

      // Calculate new point using haversine formula
      final R = 6371000; // Earth's radius in meters
      final lat1 = lastPoint.latitude * math.pi / 180;
      final lng1 = lastPoint.longitude * math.pi / 180;

      final lat2 = math.asin(math.sin(lat1) * math.cos(stepDistance / R) +
          math.cos(lat1) * math.sin(stepDistance / R) * math.cos(angle));

      final lng2 = lng1 +
          math.atan2(
              math.sin(angle) * math.sin(stepDistance / R) * math.cos(lat1),
              math.cos(stepDistance / R) - math.sin(lat1) * math.sin(lat2));

      final newPoint = LatLng(
        lat2 * 180 / math.pi,
        lng2 * 180 / math.pi,
      );

      // Calculate actual distance to new point
      final distanceToNew = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );

      totalDistance += distanceToNew;
      if (totalDistance <= maxDistance) {
        points.add(newPoint);
      }
    }

    // Generate random color
    final color = Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );

    setState(() {
      _polylines.add(
        Polyline(
          polylineId:
              PolylineId('drawing_${DateTime.now().millisecondsSinceEpoch}'),
          points: points,
          color: color,
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
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : _defaultCenter,
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
