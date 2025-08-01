import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../components/drawing_map_renderer.dart';

class DrawingService {
  static const String _baseUrl =
      'https://us-central1-walkanddraw-459410.cloudfunctions.net';

  Future<bool> saveDrawing({
    required List<ColoredPoint> points,
    required String email,
    required String? name,
    double? distance,
    String? color,
    bool isPublic = false,
    List<String>? teamIds,
  }) async {
    try {
      if (email.isEmpty) return false;

      final coordinates = points
          .map((point) => {
                'lat': point.position.latitude,
                'lng': point.position.longitude,
                'color': _colorToHex(point.color),
              })
          .toList();

      final payload = {
        'email': email,
        'username': name ?? email.split('@')[0],
        'coordinates': coordinates,
        'timestamp': DateTime.now().toIso8601String(),
        'isPublic': isPublic,
        'teamIds': teamIds ?? [],
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/saveDrawing'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print('Drawing saved successfully: ${response.body}');

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

  String _colorToHex(Color color) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b';
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
