import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'dart:async';
import 'location_permissions.dart';
import 'components/app_top_bar.dart';

class MapScreen extends StatefulWidget {
  final Credentials credentials;
  final VoidCallback onLogout;

  const MapScreen({
    super.key,
    required this.credentials,
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
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  bool _isDrawingVisible = true;
  Set<List<LatLng>> _completedDrawings = {};
  final _locationPermissionsKey = GlobalKey();

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
    _addPointsToMap(points);
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

  void _addPointsToMap(List<LatLng> points, {bool isCompleted = false}) {
    if (isCompleted) {
      _completedDrawings.add(List.from(points));
    }

    setState(() {
      _polylines.removeWhere(
          (polyline) => polyline.polylineId.value.startsWith('current_'));
      _circles.removeWhere(
          (circle) => circle.circleId.value.startsWith('current_'));

      if (!isCompleted && points.isNotEmpty) {
        for (var i = 0; i < points.length; i++) {
          _circles.add(
            Circle(
              circleId: CircleId(
                  'current_${DateTime.now().millisecondsSinceEpoch}_$i'),
              center: points[i],
              radius: 5,
              fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
              strokeColor: Colors.red,
              strokeWidth: 1,
            ),
          );
        }

        _polylines.add(
          Polyline(
            polylineId:
                PolylineId('current_${DateTime.now().millisecondsSinceEpoch}'),
            points: points,
            color: const Color.fromRGBO(255, 0, 0, 0.8),
            width: 3,
          ),
        );
      }

      for (var drawing in _completedDrawings) {
        for (var i = 0; i < drawing.length; i++) {
          _circles.add(
            Circle(
              circleId: CircleId(
                  'completed_${DateTime.now().millisecondsSinceEpoch}_$i'),
              center: drawing[i],
              radius: 5,
              fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
              strokeColor: Colors.red,
              strokeWidth: 1,
            ),
          );
        }

        _polylines.add(
          Polyline(
            polylineId: PolylineId(
                'completed_${DateTime.now().millisecondsSinceEpoch}'),
            points: drawing,
            color: const Color.fromRGBO(255, 0, 0, 0.8),
            width: 3,
          ),
        );
      }
    });
  }

  void _handlePointsUpdated(List<LatLng> points, bool isCompleted) {
    _addPointsToMap(points, isCompleted: isCompleted);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        credentials: widget.credentials,
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
        hasPolylines: _polylines.isNotEmpty,
      ),
      body: Stack(
        children: [
          GoogleMap(
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
            polylines: _isDrawingVisible ? _polylines : {},
            circles: _isDrawingVisible ? _circles : {},
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
