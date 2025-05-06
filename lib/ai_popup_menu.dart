import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ai_drawing.dart';
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
          child: const Text('AI Drawing'),
          onTap: () {
            final aiDrawing = AiDrawing(
              currentPosition: currentPosition,
              onDrawingGenerated: onDrawingGenerated,
            );
            aiDrawing.requestDrawingSuggestion();
          },
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
