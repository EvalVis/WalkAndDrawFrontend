import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class DrawingMapRenderer extends StatefulWidget {
  final List<List<LatLng>> completedDrawings;
  final List<LatLng>? currentDrawing;
  final bool isVisible;
  final Function(GoogleMapController) onMapCreated;
  final CameraPosition initialCameraPosition;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final Set<Marker> markers;

  const DrawingMapRenderer({
    super.key,
    required this.completedDrawings,
    this.currentDrawing,
    this.isVisible = true,
    required this.onMapCreated,
    required this.initialCameraPosition,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.markers = const {},
  });

  @override
  State<DrawingMapRenderer> createState() => _DrawingMapRendererState();
}

class _DrawingMapRendererState extends State<DrawingMapRenderer> {
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _updateMapPoints();
  }

  @override
  void didUpdateWidget(DrawingMapRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completedDrawings != widget.completedDrawings ||
        oldWidget.currentDrawing != widget.currentDrawing ||
        oldWidget.isVisible != widget.isVisible) {
      _updateMapPoints();
    }
  }

  void _updateMapPoints() {
    _polylines = {};
    _circles = {};

    // Add current drawing
    if (widget.currentDrawing != null && widget.currentDrawing!.isNotEmpty) {
      _addDrawingToMap(widget.currentDrawing!, false);
    }

    // Add completed drawings
    for (var drawing in widget.completedDrawings) {
      _addDrawingToMap(drawing, true);
    }
  }

  void _addDrawingToMap(List<LatLng> points, bool isCompleted) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = isCompleted ? 'completed' : 'current';

    // Add points as circles
    for (var i = 0; i < points.length; i++) {
      _circles.add(
        Circle(
          circleId: CircleId('${prefix}_${timestamp}_$i'),
          center: points[i],
          radius: 3,
          fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
          strokeColor: Colors.red,
          strokeWidth: 1,
        ),
      );
    }

    // Add polyline
    _polylines.add(
      Polyline(
        polylineId: PolylineId('${prefix}_$timestamp'),
        points: points,
        color: const Color.fromRGBO(255, 0, 0, 0.8),
        width: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: widget.onMapCreated,
      initialCameraPosition: widget.initialCameraPosition,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      markers: widget.markers,
      polylines: widget.isVisible ? _polylines : {},
      circles: widget.isVisible ? _circles : {},
      mapToolbarEnabled: false,
      zoomControlsEnabled: true,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
    );
  }
}
