import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';

enum SortOption {
  recent,
  mostVoted,
}

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
  SortOption _currentSort = SortOption.recent;
  Set<String> _votedDrawings = {};

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
      final sortBy = _currentSort == SortOption.recent ? 'date' : 'votes';
      final response = await http.get(
        Uri.parse(
          'https://us-central1-walkanddraw.cloudfunctions.net/getDrawingsSorted?sortBy=$sortBy',
        ),
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

  Future<void> _voteForDrawing(String drawingId) async {
    if (_votedDrawings.contains(drawingId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already voted for this drawing'),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://us-central1-walkanddraw.cloudfunctions.net/voteForDrawing',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'drawingId': drawingId,
          'voterEmail': widget.credentials.user.email,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _votedDrawings.add(drawingId);
          // Update the vote count in the local state
          final drawingIndex =
              _drawings.indexWhere((d) => d['id'] == drawingId);
          if (drawingIndex != -1) {
            _drawings[drawingIndex]['voteCount'] =
                (_drawings[drawingIndex]['voteCount'] ?? 0) + 1;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote recorded successfully'),
          ),
        );
      } else {
        final error = json.decode(response.body)['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to vote for drawing'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error voting for drawing: $e'),
        ),
      );
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
        title: const Text('Drawings'),
        backgroundColor: Colors.blue,
        actions: [
          // Sort dropdown
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption option) {
              setState(() {
                _currentSort = option;
              });
              _fetchDrawings();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: SortOption.recent,
                child: Text('Most Recent'),
              ),
              const PopupMenuItem(
                value: SortOption.mostVoted,
                child: Text('Most Voted'),
              ),
            ],
          ),
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
                        final voteCount = drawing['voteCount'] ?? 0;

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
                                    // Vote count and button
                                    Row(
                                      children: [
                                        Text(
                                          '$voteCount votes',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            Icons.thumb_up,
                                            color: _votedDrawings
                                                    .contains(drawingId)
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                          onPressed: () =>
                                              _voteForDrawing(drawingId),
                                        ),
                                      ],
                                    ),
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
                                    zoomControlsEnabled: true,
                                    myLocationButtonEnabled: false,
                                    compassEnabled: false,
                                    rotateGesturesEnabled: false,
                                    scrollGesturesEnabled: true,
                                    zoomGesturesEnabled: true,
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
