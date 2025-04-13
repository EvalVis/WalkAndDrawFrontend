import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';

class DrawingsScreen extends StatefulWidget {
  final Credentials credentials;

  const DrawingsScreen({
    super.key,
    required this.credentials,
  });

  @override
  State<DrawingsScreen> createState() => _DrawingsScreenState();
}

class _DrawingsScreenState extends State<DrawingsScreen> {
  List<Map<String, dynamic>> _drawings = [];
  bool _isLoading = true;
  String? _error;
  Map<String, GoogleMapController> _mapControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchDrawings();
  }

  @override
  void dispose() {
    // Dispose of all map controllers
    for (var controller in _mapControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchDrawings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = widget.credentials.user.email;
      if (email == null) {
        setState(() {
          _error = 'User email not available';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
            'https://us-central1-walkanddraw.cloudfunctions.net/getDrawings?email=$email'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _drawings = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load drawings: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Convert JSON coordinates to LatLng objects
  List<LatLng> _parseCoordinates(List<dynamic> coordinatesJson) {
    return coordinatesJson.map((coord) {
      return LatLng(
        coord['lat'].toDouble(),
        coord['lng'].toDouble(),
      );
    }).toList();
  }

  // Calculate bounds for a set of coordinates
  LatLngBounds _calculateBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = coordinates[0].latitude;
    double maxLat = coordinates[0].latitude;
    double minLng = coordinates[0].longitude;
    double maxLng = coordinates[0].longitude;

    for (var coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Drawings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDrawings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDrawings,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _drawings.isEmpty
                  ? const Center(child: Text('No drawings yet'))
                  : ListView.builder(
                      itemCount: _drawings.length,
                      itemBuilder: (context, index) {
                        final drawing = _drawings[index];
                        final coordinates =
                            _parseCoordinates(drawing['coordinates']);
                        final bounds = _calculateBounds(coordinates);
                        final drawingId = drawing['id'];

                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      drawing['username'] ?? 'Anonymous',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(drawing['createdAt']),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: GoogleMap(
                                    onMapCreated: (controller) {
                                      _mapControllers[drawingId] = controller;
                                      controller.animateCamera(
                                        CameraUpdate.newLatLngBounds(
                                            bounds, 50),
                                      );
                                    },
                                    initialCameraPosition: CameraPosition(
                                      target: coordinates.isNotEmpty
                                          ? coordinates[0]
                                          : const LatLng(0, 0),
                                      zoom: 15,
                                    ),
                                    markers: {},
                                    polylines: {
                                      Polyline(
                                        polylineId:
                                            PolylineId('drawing_$drawingId'),
                                        points: coordinates,
                                        color: Colors.red,
                                        width: 3,
                                      ),
                                    },
                                    circles: coordinates.map((point) {
                                      return Circle(
                                        circleId: CircleId(
                                            'point_${coordinates.indexOf(point)}_$drawingId'),
                                        center: point,
                                        radius: 3,
                                        fillColor: Colors.red,
                                        strokeColor: Colors.red,
                                      );
                                    }).toSet(),
                                    mapToolbarEnabled: false,
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    compassEnabled: false,
                                    rotateGesturesEnabled: false,
                                    scrollGesturesEnabled: false,
                                    tiltGesturesEnabled: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
