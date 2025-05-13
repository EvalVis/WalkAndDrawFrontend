import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ColoredPoint {
  final LatLng position;
  final Color color;

  const ColoredPoint({
    required this.position,
    required this.color,
  });
}

class ColoredDrawing {
  final List<ColoredPoint> points;

  const ColoredDrawing({
    required this.points,
  });

  // Factory to create from plain points with a single color
  factory ColoredDrawing.fromPoints(List<LatLng> points, Color color) {
    return ColoredDrawing(
      points:
          points.map((p) => ColoredPoint(position: p, color: color)).toList(),
    );
  }

  // Convenience getter for point positions
  List<LatLng> get positions => points.map((p) => p.position).toList();
}

class DrawingMapRenderer extends StatefulWidget {
  final List<ColoredDrawing> completedDrawings;
  final ColoredDrawing? currentDrawing;
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
    if (widget.currentDrawing != null &&
        widget.currentDrawing!.points.isNotEmpty) {
      _addDrawingToMap(widget.currentDrawing!, false);
    }

    // Add completed drawings
    for (var drawing in widget.completedDrawings) {
      _addDrawingToMap(drawing, true);
    }
  }

  void _addDrawingToMap(ColoredDrawing drawing, bool isCompleted) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = isCompleted ? 'completed' : 'current';

    // Add points as circles with their respective colors
    for (var i = 0; i < drawing.points.length; i++) {
      final point = drawing.points[i];
      _circles.add(
        Circle(
          circleId: CircleId('${prefix}_${timestamp}_$i'),
          center: point.position,
          radius: 3,
          fillColor: point.color,
          strokeColor: point.color,
          strokeWidth: 1,
        ),
      );
    }

    // Add polylines between consecutive points with matching colors
    if (drawing.points.length > 1) {
      for (var i = 0; i < drawing.points.length - 1; i++) {
        final startPoint = drawing.points[i];
        final endPoint = drawing.points[i + 1];

        _polylines.add(
          Polyline(
            polylineId: PolylineId('${prefix}_${timestamp}_segment_$i'),
            points: [startPoint.position, endPoint.position],
            color:
                endPoint.color, // Use the color of the end point for the line
            width: 3,
          ),
        );
      }
    }
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
