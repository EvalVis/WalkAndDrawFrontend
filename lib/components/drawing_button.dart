import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/drawing_service.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

class DrawingButton extends StatefulWidget {
  final Credentials credentials;
  final Function(List<LatLng>, bool) onPointsUpdated;

  const DrawingButton({
    super.key,
    required this.credentials,
    required this.onPointsUpdated,
  });

  @override
  State<DrawingButton> createState() => _DrawingButtonState();
}

class _DrawingButtonState extends State<DrawingButton> {
  bool _isManualDrawing = false;
  List<LatLng> _currentDrawingPoints = [];
  Position? _lastDrawingPosition;
  double _totalDistance = 0;
  StreamSubscription<Position>? _positionStreamSubscription;
  final DrawingService _drawingService = DrawingService();

  void _startDrawing() {
    if (_currentDrawingPoints.isNotEmpty) {
      widget.onPointsUpdated(_currentDrawingPoints, true);
    }

    _lastDrawingPosition = null;
    setState(() {
      _isManualDrawing = true;
      _currentDrawingPoints = [];
      _totalDistance = 0;
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (_isManualDrawing) {
        if (_lastDrawingPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastDrawingPosition!.latitude,
            _lastDrawingPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _totalDistance += distance;
        }
        _lastDrawingPosition = position;

        setState(() {
          final newPoint = LatLng(position.latitude, position.longitude);
          if (_currentDrawingPoints.isEmpty ||
              newPoint != _currentDrawingPoints.last) {
            _currentDrawingPoints.add(newPoint);
            widget.onPointsUpdated(_currentDrawingPoints, false);
          }
        });
      }
    });
  }

  void _stopDrawing() async {
    _positionStreamSubscription?.cancel();

    if (_currentDrawingPoints.isNotEmpty) {
      widget.onPointsUpdated(_currentDrawingPoints, true);

      await _drawingService.saveDrawing(
        points: _currentDrawingPoints,
        email: widget.credentials.user.email ?? '',
        name: widget.credentials.user.name,
        distance: _totalDistance,
      );

      setState(() {
        _isManualDrawing = false;
        _currentDrawingPoints = [];
        _totalDistance = 0;
      });
    } else {
      setState(() {
        _isManualDrawing = false;
      });
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isManualDrawing ? _stopDrawing : _startDrawing,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isManualDrawing ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
      ),
      child: Text(_isManualDrawing ? 'Stop Drawing' : 'Start Drawing'),
    );
  }
}
