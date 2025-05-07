import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DrawingCoordinatesAiQuery {
  static const String _baseUrl =
      'https://us-central1-walkanddraw.cloudfunctions.net/callGemini';

  Future<List<LatLng>> getDrawingCoordinates(Position position) async {
    final prompt =
        '''Given coordinates (${position.latitude}, ${position.longitude}), create a simple stick-figure style drawing by providing a sequence of coordinates. Requirements:
1. First point must be (${position.latitude}, ${position.longitude}).
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
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': prompt}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to get drawing coordinates');
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final body = responseData['response'] as String;
      final jsonResponse =
          body.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> coordinates = json.decode(jsonResponse);
      return coordinates
          .map((coord) => LatLng(
                (coord['lat'] as num).toDouble(),
                (coord['lng'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get drawing coordinates');
    }
  }
}
