import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'vote_button.dart';

class DrawingRecord extends StatefulWidget {
  final Map<String, dynamic> drawing;
  final String voterEmail;
  final bool hasVoted;
  final Function(String) onVoteSuccess;

  const DrawingRecord({
    super.key,
    required this.drawing,
    required this.voterEmail,
    required this.hasVoted,
    required this.onVoteSuccess,
  });

  @override
  State<DrawingRecord> createState() => _DrawingRecordState();
}

class _DrawingRecordState extends State<DrawingRecord> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  List<LatLng> _parseCoordinates(List<dynamic> coordinatesJson) {
    return coordinatesJson.map((coord) {
      return LatLng(
        coord['lat'].toDouble(),
        coord['lng'].toDouble(),
      );
    }).toList();
  }

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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'XXXX-XX-XX';

    try {
      final date = DateTime.parse(dateString);
      return '/${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return 'XXXX-XX-XX';
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = _parseCoordinates(widget.drawing['coordinates']);
    final bounds = _calculateBounds(coordinates);
    final drawingId = widget.drawing['id'];
    final voteCount = widget.drawing['voteCount'] ?? 0;

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
                  widget.drawing['username'] ?? 'Anonymous',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Vote count and button
                VoteButton(
                  drawingId: drawingId,
                  voterEmail: widget.voterEmail,
                  voteCount: voteCount,
                  hasVoted: widget.hasVoted,
                  onVoteSuccess: widget.onVoteSuccess,
                ),
                Text(
                  _formatDate(widget.drawing['createdAt']),
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
                  _mapController = controller;
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 50),
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
                    polylineId: PolylineId('drawing_$drawingId'),
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
  }
}
