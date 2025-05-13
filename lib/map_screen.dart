import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'location_permissions.dart';
import 'components/app_top_bar.dart';
import 'components/drawing_map_renderer.dart';

class MapScreen extends StatefulWidget {
  final GoogleSignInAccount user;
  final VoidCallback onLogout;

  const MapScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  bool _locationPermissionGranted = false;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isDrawingVisible = true;
  List<ColoredDrawing> _completedDrawings = [];
  ColoredDrawing? _currentDrawing;
  final _locationPermissionsKey = GlobalKey();
  Color _currentDrawingColor = Colors.red;

  final LatLng _defaultCenter = const LatLng(54.687157, 25.279652);

  void _handlePermissionGranted(bool granted) async {
    if (mounted) {
      setState(() {
        _locationPermissionGranted = granted;
      });
      if (granted) {
        await _streamCurrentLocation();
      }
    }
  }

  void _handleDrawingGenerated(List<LatLng> points) {
    setState(() {
      _currentDrawing = ColoredDrawing.fromPoints(points, _currentDrawingColor);
    });
  }

  Future<void> _streamCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _updateCurrentLocationMarker();
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _currentPosition = position;
        });
      });
    } catch (e) {
      print('Error getting current position: $e');
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    final latLng =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 15.0,
        ),
      ),
    );
  }

  void _handlePointsUpdated(ColoredDrawing drawing, bool isCompleted) {
    setState(() {
      if (isCompleted) {
        _completedDrawings.add(drawing);
        _currentDrawing = null;
      } else {
        _currentDrawing = drawing;
      }
    });
  }

  void _handleColorChanged(Color color) {
    setState(() {
      _currentDrawingColor = color;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        user: widget.user,
        onLogout: widget.onLogout,
        currentPosition: _currentPosition,
        onDrawingGenerated: _handleDrawingGenerated,
        onPointsUpdated: _handlePointsUpdated,
        isDrawingVisible: _isDrawingVisible,
        onToggleVisibility: () {
          setState(() {
            _isDrawingVisible = !_isDrawingVisible;
          });
        },
        hasPolylines: _currentDrawing != null || _completedDrawings.isNotEmpty,
        onColorChanged: _handleColorChanged,
      ),
      body: Stack(
        children: [
          DrawingMapRenderer(
            completedDrawings: _completedDrawings,
            currentDrawing: _currentDrawing,
            isVisible: _isDrawingVisible,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : _defaultCenter,
              zoom: 15.0,
            ),
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: _locationPermissionGranted,
            markers: _markers,
          ),
          LocationPermissions(
            key: _locationPermissionsKey,
            onPermissionGranted: _handlePermissionGranted,
          ),
        ],
      ),
    );
  }
}
