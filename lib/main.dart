import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Debug: Print the API key from environment
  final apiKey = Platform.environment['GOOGLE_MAPS_API_KEY'];
  debugPrint('API Key from environment: ${apiKey ?? 'Not found'}');

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

  final LatLng _center = const LatLng(-34.0, 151.0);

  @override
  void initState() {
    super.initState();
    debugPrint('MapScreen initialized');
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return;
    }

    setState(() {
      _locationPermissionGranted = true;
    });

    // Get current position
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      debugPrint(
        'Current position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    debugPrint('Map controller created successfully');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MapScreen');
    return Scaffold(
      appBar: AppBar(title: const Text('Walk and Draw')),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target:
              _currentPosition != null
                  ? LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  )
                  : _center,
          zoom: 11.0,
        ),
        myLocationEnabled: _locationPermissionGranted,
        myLocationButtonEnabled: _locationPermissionGranted,
        markers: {
          Marker(
            markerId: const MarkerId('sydney'),
            position: _center,
            infoWindow: const InfoWindow(title: 'Sydney', snippet: 'Australia'),
          ),
        },
      ),
    );
  }
}
