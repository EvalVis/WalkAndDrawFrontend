import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'services/drawing_coordinates_ai_query.dart';
import 'services/drawing_generator.dart';
import 'drawing_suggestion.dart';

class AiPopupMenu extends StatelessWidget {
  final Position? currentPosition;
  final Function(List<LatLng>) onDrawingGenerated;
  final bool isDrawingVisible;
  final VoidCallback onToggleVisibility;
  final bool hasPolylines;

  const AiPopupMenu({
    super.key,
    required this.currentPosition,
    required this.onDrawingGenerated,
    required this.isDrawingVisible,
    required this.onToggleVisibility,
    required this.hasPolylines,
  });

  Future<void> _handleDrawingRequest() async {
    final drawingGeneration = DrawingGenerator(
      currentPosition: currentPosition,
      onDrawingGenerated: onDrawingGenerated,
    );

    try {
      final drawingCoordinatesAiQuery = DrawingCoordinatesAiQuery();
      final coordinates = await drawingCoordinatesAiQuery
          .getDrawingCoordinates(currentPosition!);
      drawingGeneration.generateFromCoordinates(coordinates);
    } catch (e) {
      drawingGeneration.generateSampleDrawing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'suggestion',
          child: const Text('AI Suggestion'),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const DrawingSuggestion(),
            );
          },
        ),
        PopupMenuItem(
          value: 'ai_draw',
          onTap: _handleDrawingRequest,
          child: const Text('AI Drawing'),
        ),
        if (hasPolylines)
          PopupMenuItem(
            value: 'toggle',
            onTap: onToggleVisibility,
            child: Row(
              children: [
                Icon(
                  isDrawingVisible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(isDrawingVisible ? 'Hide AI Drawing' : 'Show AI Drawing'),
              ],
            ),
          ),
      ],
    );
  }
}
