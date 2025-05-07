import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class DrawingGenerator {
  final Position? currentPosition;
  final Function(List<LatLng>) onDrawingGenerated;

  const DrawingGenerator({
    required this.currentPosition,
    required this.onDrawingGenerated,
  });

  void generateFromCoordinates(List<LatLng> points) {
    onDrawingGenerated(points);
  }

  void generateSampleDrawing() {
    if (currentPosition == null) return;

    final random = math.Random();
    final numPoints = random.nextInt(81) + 20;
    final points = <LatLng>[];

    final startPoint =
        LatLng(currentPosition!.latitude, currentPosition!.longitude);
    points.add(startPoint);

    double totalDistance = 0;
    final maxDistance = 20000;
    final maxStepDistance = 200.0;

    for (int i = 1; i < numPoints; i++) {
      final lastPoint = points.last;

      final distanceToStart = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        startPoint.latitude,
        startPoint.longitude,
      );

      if (totalDistance + distanceToStart >= maxDistance) {
        points.add(startPoint);
        break;
      }

      final angle = random.nextDouble() * 2 * math.pi;
      final stepDistance = random.nextDouble() * maxStepDistance;

      final R = 6371000;
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

      final distanceToNew = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );

      final newPointToStart = Geolocator.distanceBetween(
        newPoint.latitude,
        newPoint.longitude,
        startPoint.latitude,
        startPoint.longitude,
      );

      if (distanceToNew <= maxStepDistance &&
          totalDistance + distanceToNew + newPointToStart <= maxDistance) {
        points.add(newPoint);
        totalDistance += distanceToNew;
      } else {
        if (totalDistance + distanceToStart <= maxDistance) {
          points.add(startPoint);
        }
        break;
      }
    }

    if (points.last != startPoint) {
      final finalDistanceToStart = Geolocator.distanceBetween(
        points.last.latitude,
        points.last.longitude,
        startPoint.latitude,
        startPoint.longitude,
      );

      if (totalDistance + finalDistanceToStart <= maxDistance) {
        points.add(startPoint);
      }
    }

    onDrawingGenerated(points);
  }
}
