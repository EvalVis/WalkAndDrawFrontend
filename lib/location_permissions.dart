import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissions extends StatefulWidget {
  final Function(bool) onPermissionGranted;

  const LocationPermissions({
    super.key,
    required this.onPermissionGranted,
  });

  @override
  State<LocationPermissions> createState() => _LocationPermissionsState();
}

class _LocationPermissionsState extends State<LocationPermissions> {
  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  // Make sure this is not rerendered on state change. So: save the permissions.

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    widget.onPermissionGranted(true);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
