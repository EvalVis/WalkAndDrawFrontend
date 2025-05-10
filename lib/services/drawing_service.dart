import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DrawingService {
  static const String _baseUrl =
      'https://us-central1-walkanddraw-459410.cloudfunctions.net';

  Future<bool> saveDrawing({
    required List<LatLng> points,
    required String email,
    required String? name,
    double? distance,
  }) async {
    try {
      if (email.isEmpty) return false;

      final coordinates = points
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
              })
          .toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/saveDrawing'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': name ?? email.split('@')[0],
          'coordinates': coordinates,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('Drawing saved successfully: ${response.body}');

        // If distance is provided, update it too
        if (distance != null) {
          await updateDistance(
            email: email,
            name: name,
            distance: distance,
          );
        }

        return true;
      } else {
        print('Failed to save drawing: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error saving drawing: $e');
      return false;
    }
  }

  Future<bool> updateDistance({
    required String email,
    required String? name,
    required double distance,
  }) async {
    try {
      if (email.isEmpty) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/updateDistance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': name,
          'distance': distance,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('Distance updated successfully: ${response.body}');
        return true;
      } else {
        print('Failed to update distance: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating distance: $e');
      return false;
    }
  }
}
