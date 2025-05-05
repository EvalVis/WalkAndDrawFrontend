import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;

class AiDrawing extends StatefulWidget {
  final Position? currentPosition;
  final Function(List<LatLng>) onDrawingGenerated;

  const AiDrawing({
    super.key,
    required this.currentPosition,
    required this.onDrawingGenerated,
  });

  @override
  State<AiDrawing> createState() => _AiDrawingState();
}

class _AiDrawingState extends State<AiDrawing> {
  bool _isLoading = false;

  Future<void> _requestDrawingSuggestion() async {
    if (widget.currentPosition == null) {
      print('Cannot request drawing: position is null');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prompt =
          '''Given coordinates (${widget.currentPosition!.latitude}, ${widget.currentPosition!.longitude}), create a simple stick-figure style drawing by providing a sequence of coordinates. Requirements:
1. First point must be (${widget.currentPosition!.latitude}, ${widget.currentPosition!.longitude}).
2. Last point must be the same as the first point to close the shape.
3. Each point should be within 100 meters of the previous point to ensure smooth lines.
4. Total path distance (summed distance between all points) must not exceed 20 kilometers.
5. Generate between 40-60 points to create a recognizable drawing.
6. IMPORTANT: Do not create simple linear progressions of coordinates. Each new point should have varying changes in both latitude and longitude to create actual shapes and curves.
7. Create a simple stick-figure style drawing like:
   - A cat (draw ears, head, body, legs, tail with varying angles)
   - A house (draw roof, walls, door with actual corners)
   - A stick figure (draw head, body, arms, legs with proper angles)
8. Return ONLY a JSON array in this exact format, with no other text: [{"lat": x1, "lng": y1}, {"lat": x2, "lng": y2}, ...]''';

      print('Sending prompt to Cloud Function');

      final response = await http.post(
        Uri.parse(
            'https://us-central1-walkanddraw.cloudfunctions.net/callGemini'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': prompt}),
      );

      print('Cloud Function response received:');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData =
              json.decode(response.body) as Map<String, dynamic>;
          final geminiResponse = responseData['response'] as String;

          final jsonResponse = geminiResponse
              .trim()
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          print('Attempting to parse JSON response: $jsonResponse');

          final List<dynamic> coordinates = json.decode(jsonResponse);
          final points = <LatLng>[];
          double totalDistance = 0;

          for (var i = 0; i < coordinates.length; i++) {
            final coord = coordinates[i];
            final point =
                LatLng(coord['lat'].toDouble(), coord['lng'].toDouble());
            points.add(point);

            if (i > 0) {
              final distance = Geolocator.distanceBetween(
                points[i - 1].latitude,
                points[i - 1].longitude,
                point.latitude,
                point.longitude,
              );
              totalDistance += distance;
            }
          }

          print('Total path distance: ${totalDistance / 1000} kilometers');
          print('Number of points: ${points.length}');

          widget.onDrawingGenerated(points);
        } catch (e) {
          print('Error parsing Cloud Function response: $e');
          print('Falling back to sample drawing due to parsing error');
          _createSampleDrawing();
        }
      } else {
        print('Cloud Function returned error ${response.statusCode}');
        print('Falling back to sample drawing');
        _createSampleDrawing();
      }
    } catch (e, stackTrace) {
      print('Error getting drawing suggestion: $e');
      print('Stack trace: $stackTrace');
      print('Falling back to sample drawing due to error');
      _createSampleDrawing();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createSampleDrawing() {
    if (widget.currentPosition == null) return;

    final random = math.Random();
    final numPoints = random.nextInt(81) + 20;
    final points = <LatLng>[];

    final startPoint = LatLng(
        widget.currentPosition!.latitude, widget.currentPosition!.longitude);
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

    widget.onDrawingGenerated(points);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuItem(
      value: 'ai_draw',
      child: Row(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              ),
            ),
          Text(_isLoading ? 'Generating...' : 'AI Drawing'),
        ],
      ),
    );
  }
}
