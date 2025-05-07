import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'leaderboard_screen.dart';
import 'drawings_screen.dart';
import 'login_screen.dart';
import 'location_permissions.dart';
import 'ai_popup_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Credentials? _credentials;
  late Auth0 auth0;

  @override
  void initState() {
    super.initState();
    auth0 = Auth0('dev-nfxagfo4wp0f5ee7.us.auth0.com',
        'Cj3Mrzu9h99Nd2ZCzWC5NFrJoxKzftRa');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk and Draw',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _credentials == null
          ? LoginScreen(
              auth0: auth0,
              onLogin: (credentials) {
                setState(() {
                  _credentials = credentials;
                });
              },
            )
          : MainApp(
              credentials: _credentials!,
              onLogout: _handleLogout,
            ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await auth0
          .webAuthentication(scheme: 'com.programmersdiary.walkanddraw')
          .logout();

      setState(() {
        _credentials = null;
      });
    } catch (e) {
      print('Logout error: $e');
    }
  }
}

class MapScreen extends StatefulWidget {
  final Credentials credentials;
  final VoidCallback onLogout;

  const MapScreen({
    super.key,
    required this.credentials,
    required this.onLogout,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  bool _locationPermissionGranted = false;
  Position? _currentPosition;
  Position? _lastDrawingPosition;
  double _totalDistance = 0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  bool _isDrawingVisible = true;
  bool _isManualDrawing = false;
  List<LatLng> _currentDrawingPoints = [];
  Set<List<LatLng>> _completedDrawings = {};
  Set<List<LatLng>> _savedDrawings = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  final _locationPermissionsKey = GlobalKey();

  final LatLng _defaultCenter = const LatLng(54.687157, 25.279652);

  void _handlePermissionGranted(bool granted) async {
    if (mounted) {
      setState(() {
        _locationPermissionGranted = granted;
      });
      if (granted) {
        await _streamCurrentLocation();
      }
    }
  }

  void _handleDrawingGenerated(List<LatLng> points) {
    _addPointsToMap(points);
  }

  Future<void> _streamCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _updateCurrentLocationMarker();
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _currentPosition = position;
        });
      });
    } catch (e) {
      print('Error getting current position: $e');
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    final latLng =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 15.0,
        ),
      ),
    );
  }

  void _addPointsToMap(List<LatLng> points, {bool isCompleted = false}) {
    if (isCompleted) {
      _completedDrawings.add(List.from(points));
    }

    setState(() {
      _polylines.removeWhere(
          (polyline) => polyline.polylineId.value.startsWith('current_'));
      _circles.removeWhere(
          (circle) => circle.circleId.value.startsWith('current_'));

      if (!isCompleted && points.isNotEmpty) {
        for (var i = 0; i < points.length; i++) {
          _circles.add(
            Circle(
              circleId: CircleId(
                  'current_${DateTime.now().millisecondsSinceEpoch}_$i'),
              center: points[i],
              radius: 5,
              fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
              strokeColor: Colors.red,
              strokeWidth: 1,
            ),
          );
        }

        _polylines.add(
          Polyline(
            polylineId:
                PolylineId('current_${DateTime.now().millisecondsSinceEpoch}'),
            points: points,
            color: const Color.fromRGBO(255, 0, 0, 0.8),
            width: 3,
          ),
        );
      }

      for (var drawing in _completedDrawings) {
        for (var i = 0; i < drawing.length; i++) {
          _circles.add(
            Circle(
              circleId: CircleId(
                  'completed_${DateTime.now().millisecondsSinceEpoch}_$i'),
              center: drawing[i],
              radius: 5,
              fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
              strokeColor: Colors.red,
              strokeWidth: 1,
            ),
          );
        }

        _polylines.add(
          Polyline(
            polylineId: PolylineId(
                'completed_${DateTime.now().millisecondsSinceEpoch}'),
            points: drawing,
            color: const Color.fromRGBO(255, 0, 0, 0.8),
            width: 3,
          ),
        );
      }
    });
  }

  void _startDrawing() {
    if (_currentDrawingPoints.isNotEmpty) {
      _addPointsToMap(_currentDrawingPoints, isCompleted: true);
    }

    _lastDrawingPosition = null;
    setState(() {
      _isManualDrawing = true;
      _currentDrawingPoints = [];
      _totalDistance = 0;
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (_isManualDrawing) {
        if (_lastDrawingPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastDrawingPosition!.latitude,
            _lastDrawingPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _totalDistance += distance;
          print(
              'Total distance walked: ${(_totalDistance / 1000).toStringAsFixed(2)} km');
        }
        _lastDrawingPosition = position;

        setState(() {
          final newPoint = LatLng(position.latitude, position.longitude);
          if (_currentDrawingPoints.isEmpty ||
              newPoint != _currentDrawingPoints.last) {
            _currentDrawingPoints.add(newPoint);
            _addPointsToMap(_currentDrawingPoints);
          }
        });
      }
    });
  }

  void _stopDrawing() {
    _positionStreamSubscription?.cancel();
    setState(() {
      _isManualDrawing = false;
      if (_currentDrawingPoints.isNotEmpty) {
        _addPointsToMap(_currentDrawingPoints, isCompleted: true);
        _saveDrawingToCloud(_currentDrawingPoints);
        _savedDrawings.add(List.from(_currentDrawingPoints));
        _currentDrawingPoints = [];
      }
    });

    _updateDistanceInCloud();
    _totalDistance = 0;
  }

  Future<void> _saveDrawingToCloud(List<LatLng> points) async {
    try {
      final email = widget.credentials.user.email;
      final name = widget.credentials.user.name;

      if (email == null) return;

      final coordinates = points
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
              })
          .toList();

      final response = await http.post(
        Uri.parse(
            'https://us-central1-walkanddraw.cloudfunctions.net/saveDrawing'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': name ?? email.split('@')[0],
          'coordinates': coordinates,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to save drawing: ${response.body}');
      } else {
        print('Drawing saved successfully: ${response.body}');
      }
    } catch (e) {
      print('Error saving drawing: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _updateDistanceInCloud() async {
    try {
      final email = widget.credentials.user.email;
      final name = widget.credentials.user.name;

      if (email == null) return;

      final response = await http.post(
        Uri.parse(
            'https://us-central1-walkanddraw.cloudfunctions.net/updateDistance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': name,
          'distance': _totalDistance,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to update distance: ${response.body}');
      } else {
        print('Distance updated successfully: ${response.body}');
      }
    } catch (e) {
      print('Error updating distance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                      widget.credentials.user.email ?? 'User',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: widget.onLogout,
                ),
                ElevatedButton(
                  onPressed: _isManualDrawing ? _stopDrawing : _startDrawing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isManualDrawing ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      Text(_isManualDrawing ? 'Stop Drawing' : 'Start Drawing'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AiPopupMenu(
                    key: GlobalKey(),
                    currentPosition: _currentPosition,
                    onDrawingGenerated: _handleDrawingGenerated,
                    isDrawingVisible: _isDrawingVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _isDrawingVisible = !_isDrawingVisible;
                      });
                    },
                    hasPolylines: _polylines.isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : _defaultCenter,
              zoom: 15.0,
            ),
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: _locationPermissionGranted,
            markers: _markers,
            polylines: _isDrawingVisible ? _polylines : {},
            circles: _isDrawingVisible ? _circles : {},
          ),
          LocationPermissions(
            key: _locationPermissionsKey,
            onPermissionGranted: _handlePermissionGranted,
          ),
        ],
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  final Credentials credentials;
  final VoidCallback onLogout;

  const MainApp({
    super.key,
    required this.credentials,
    required this.onLogout,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapScreen(
            credentials: widget.credentials,
            onLogout: widget.onLogout,
          ),
          LeaderboardScreen(
            credentials: widget.credentials,
          ),
          DrawingsScreen(
            credentials: widget.credentials,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush),
            label: 'Drawings',
          ),
        ],
      ),
    );
  }
}
