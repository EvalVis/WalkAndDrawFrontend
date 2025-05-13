import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/drawing_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'drawing_map_renderer.dart';

class DrawingButton extends StatefulWidget {
  final GoogleSignInAccount user;
  final Function(ColoredDrawing, bool) onPointsUpdated;
  final Function(Color)? onColorChanged;

  const DrawingButton({
    super.key,
    required this.user,
    required this.onPointsUpdated,
    this.onColorChanged,
  });

  @override
  State<DrawingButton> createState() => _DrawingButtonState();
}

class _DrawingButtonState extends State<DrawingButton> {
  bool _isManualDrawing = false;
  List<ColoredPoint> _currentDrawingPoints = [];
  Position? _lastDrawingPosition;
  double _totalDistance = 0;
  StreamSubscription<Position>? _positionStreamSubscription;
  final DrawingService _drawingService = DrawingService();
  Color _currentColor = Colors.red;

  Color get currentColor => _currentColor;
  bool get isDrawing => _isManualDrawing;

  void _startDrawing() {
    if (_currentDrawingPoints.isNotEmpty) {
      final completedDrawing = ColoredDrawing(
        points: List.from(_currentDrawingPoints),
      );
      widget.onPointsUpdated(completedDrawing, true);
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
          final newPoint = ColoredPoint(
            position: LatLng(position.latitude, position.longitude),
            color: _currentColor,
          );

          if (_currentDrawingPoints.isEmpty ||
              newPoint.position != _currentDrawingPoints.last.position) {
            _currentDrawingPoints.add(newPoint);
            final currentDrawing = ColoredDrawing(
              points: List.from(_currentDrawingPoints),
            );
            widget.onPointsUpdated(currentDrawing, false);
          }
        });
      }
    });
  }

  void _stopDrawing() async {
    _positionStreamSubscription?.cancel();

    if (_currentDrawingPoints.isNotEmpty) {
      final completedDrawing = ColoredDrawing(
        points: List.from(_currentDrawingPoints),
      );
      widget.onPointsUpdated(completedDrawing, true);

      // Convert to LatLng points for the service
      final latLngPoints =
          _currentDrawingPoints.map((cp) => cp.position).toList();

      await _drawingService.saveDrawing(
        points: latLngPoints,
        email: widget.user.email,
        name: widget.user.displayName,
        distance: _totalDistance,
        color: _currentColor.value.toString(), // Save last color as string
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

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentColor,
            onColorChanged: (color) {
              setState(() => _currentColor = color);
              if (widget.onColorChanged != null) {
                widget.onColorChanged!(color);
              }
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: true,
            displayThumbColor: true,
            paletteType: PaletteType.hsv,
            pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Done'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _isManualDrawing ? _stopDrawing : _startDrawing,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isManualDrawing ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
            minimumSize: _isManualDrawing ? const Size(120, 36) : null,
          ),
          child: Text(_isManualDrawing ? 'Stop Drawing' : 'Start Drawing'),
        ),
        if (_isManualDrawing)
          GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
