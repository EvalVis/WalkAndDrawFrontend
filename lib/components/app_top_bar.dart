import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../ai_popup_menu.dart';
import 'drawing_button.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Credentials credentials;
  final VoidCallback onLogout;
  final Position? currentPosition;
  final Function(List<LatLng>) onDrawingGenerated;
  final Function(List<LatLng>, bool) onPointsUpdated;
  final bool isDrawingVisible;
  final VoidCallback onToggleVisibility;
  final bool hasPolylines;

  const AppTopBar({
    super.key,
    required this.credentials,
    required this.onLogout,
    required this.currentPosition,
    required this.onDrawingGenerated,
    required this.onPointsUpdated,
    required this.isDrawingVisible,
    required this.onToggleVisibility,
    required this.hasPolylines,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Walk and Draw'),
      centerTitle: false,
      actions: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    credentials.user.email ?? 'User',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: onLogout,
              ),
              DrawingButton(
                credentials: credentials,
                onPointsUpdated: onPointsUpdated,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AiPopupMenu(
                  key: GlobalKey(),
                  currentPosition: currentPosition,
                  onDrawingGenerated: onDrawingGenerated,
                  isDrawingVisible: isDrawingVisible,
                  onToggleVisibility: onToggleVisibility,
                  hasPolylines: hasPolylines,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
