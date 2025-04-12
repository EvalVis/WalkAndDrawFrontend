import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'dart:async';

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
          ? _buildLoginScreen()
          : MapScreen(
              credentials: _credentials!,
              onLogout: _handleLogout,
            ),
    );
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _handleLogin,
          child: const Text('Log in'),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    try {
      final credentials = await auth0
          .webAuthentication(scheme: 'com.programmersdiary.walkanddraw')
          .login();

      setState(() {
        _credentials = credentials;
      });
    } catch (e) {
      print('Login error: $e');
    }
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
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  GenerativeModel? _model;
  bool _isLoading = false;
  bool _isDrawingVisible = true;
  bool _isGettingSuggestion = false;
  bool _isManualDrawing = false;
  List<LatLng> _currentDrawingPoints = [];
  Set<List<LatLng>> _completedDrawings = {};
  StreamSubscription<Position>? _positionStreamSubscription;

  // Default center (will be updated when we get current location)
  final LatLng _defaultCenter =
      const LatLng(54.687157, 25.279652); // Vilnius coordinates

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _initializeGemini();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGemini() async {
    try {
      final apiKey =
          await const MethodChannel('com.programmersdiary.walk_and_draw/config')
              .invokeMethod<String>('getGeminiApiKey');

      if (apiKey != null && apiKey.isNotEmpty) {
        _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        );
      }
    } catch (e) {
      print('Error initializing Gemini: $e');
    }
  }

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

    setState(() {
      _locationPermissionGranted = true;
    });

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _updateCurrentLocationMarker();
    } catch (e) {
      // Ignore position error as the app can still work with default location
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
      // Clear only current drawing elements
      _polylines.removeWhere((polyline) => polyline.polylineId.value.startsWith('current_'));
      _circles.removeWhere((circle) => circle.circleId.value.startsWith('current_'));
      
      // Add current drawing if there are points
      if (!isCompleted && points.isNotEmpty) {
        // Add circles for current points
        for (var i = 0; i < points.length; i++) {
          _circles.add(
            Circle(
              circleId: CircleId('current_${DateTime.now().millisecondsSinceEpoch}_$i'),
              center: points[i],
              radius: 5,
              fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
              strokeColor: Colors.red,
              strokeWidth: 1,
            ),
          );
        }

        // Add polyline for current drawing
        _polylines.add(
          Polyline(
            polylineId: PolylineId('current_${DateTime.now().millisecondsSinceEpoch}'),
            points: points,
            color: const Color.fromRGBO(255, 0, 0, 0.8),
            width: 3,
          ),
        );
      }

      // Always show completed drawings
      for (var drawing in _completedDrawings) {
        // Add circles for completed drawing points
        for (var i = 0; i < drawing.length; i++) {
          _circles.add(
            Circle(
              circleId: CircleId('completed_${DateTime.now().millisecondsSinceEpoch}_$i'),
              center: drawing[i],
              radius: 5,
              fillColor: const Color.fromRGBO(255, 0, 0, 0.8),
              strokeColor: Colors.red,
              strokeWidth: 1,
            ),
          );
        }

        // Add polyline for completed drawing
        _polylines.add(
          Polyline(
            polylineId: PolylineId('completed_${DateTime.now().millisecondsSinceEpoch}'),
            points: drawing,
            color: const Color.fromRGBO(255, 0, 0, 0.8),
            width: 3,
          ),
        );
      }
    });
  }

  Future<void> _requestDrawingSuggestion() async {
    if (_model == null || _currentPosition == null) {
      print(
          'Cannot request drawing: model=${_model != null}, position=${_currentPosition != null}');
      return;
    }

    setState(() {
      _isLoading = true;
      // Clear previous drawing
      _polylines.clear();
      _circles.clear();
    });

    try {
      final prompt =
          '''Given coordinates (${_currentPosition!.latitude}, ${_currentPosition!.longitude}), create a simple stick-figure style drawing by providing a sequence of coordinates. Requirements:
1. First point must be (${_currentPosition!.latitude}, ${_currentPosition!.longitude}).
2. Last point must be the same as the first point to close the shape.
3. Each point should be within 100 meters of the previous point to ensure smooth lines.
4. Total path distance (summed distance between all points) must not exceed 20 kilometers.
5. Generate between 40-60 points to create a recognizable drawing.
6. IMPORTANT: Do not create simple linear progressions of coordinates. Each new point should have varying changes in both latitude and longitude to create actual shapes and curves.
7. Create a simple stick-figure style drawing like:
   - A cat (draw ears, head, body, legs, tail with varying angles)
   - A house (draw roof, walls, door with actual corners)
   - A stick figure (draw head, body, arms, legs with proper angles)
8. Return ONLY a JSON array in this exact format, with no other text: [{"lat": x1, "lng": y1}, {"lat": x2, "lng": y2}, ...]''';

      print('Sending prompt to Gemini: $prompt');
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      print('Gemini response received:');
      print('Response text: ${response.text}');
      if (response.promptFeedback != null) {
        print('Prompt feedback: ${response.promptFeedback}');
      }

      if (response.text != null) {
        try {
          // Try to parse the JSON response
          final jsonResponse = response.text!
              .trim()
              .replaceAll('```json', '') // Remove markdown code block start
              .replaceAll('```', '') // Remove markdown code block end
              .trim(); // Remove any extra whitespace

          print('Attempting to parse JSON response: $jsonResponse');

          final List<dynamic> coordinates = json.decode(jsonResponse);
          final points = <LatLng>[];
          double totalDistance = 0;

          // Parse each coordinate and create LatLng points
          for (var i = 0; i < coordinates.length; i++) {
            final coord = coordinates[i];
            final point =
                LatLng(coord['lat'].toDouble(), coord['lng'].toDouble());
            points.add(point);

            // Calculate distance between consecutive points
            if (i > 0) {
              final distance = Geolocator.distanceBetween(
                points[i - 1].latitude,
                points[i - 1].longitude,
                point.latitude,
                point.longitude,
              );
              totalDistance += distance;
            }
          }

          print('Total path distance: ${totalDistance / 1000} kilometers');
          print('Number of points: ${points.length}');

          _addPointsToMap(points);
        } catch (e) {
          print('Error parsing Gemini response: $e');
          print('Falling back to sample drawing due to parsing error');
          _createSampleDrawing();
        }
      } else {
        print('Gemini response text is null, falling back to sample drawing');
        _createSampleDrawing();
      }
    } catch (e, stackTrace) {
      print('Error getting drawing suggestion: $e');
      print('Stack trace: $stackTrace');
      print('Falling back to sample drawing due to error');
      _createSampleDrawing();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createSampleDrawing() {
    if (_currentPosition == null) return;

    final random = math.Random();
    final numPoints =
        random.nextInt(81) + 20; // Random between 20 and 100 points
    final points = <LatLng>[];

    // Start from current location
    final startPoint =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    points.add(startPoint);

    double totalDistance = 0;
    final maxDistance = 20000; // 20 kilometers in meters
    final maxStepDistance = 200.0; // Maximum 200m per step

    for (int i = 1; i < numPoints; i++) {
      final lastPoint = points.last;

      // Calculate distance to start point
      final distanceToStart = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        startPoint.latitude,
        startPoint.longitude,
      );

      // If adding another point would make it impossible to return to start within limit
      if (totalDistance + distanceToStart >= maxDistance) {
        // Add the start point to close the path
        points.add(startPoint);
        break;
      }

      // Generate random angle and distance
      final angle = random.nextDouble() * 2 * math.pi;
      final stepDistance = random.nextDouble() * maxStepDistance;

      // Calculate new point using haversine formula
      final R = 6371000; // Earth's radius in meters
      final lat1 = lastPoint.latitude * math.pi / 180;
      final lng1 = lastPoint.longitude * math.pi / 180;

      final lat2 = math.asin(math.sin(lat1) * math.cos(stepDistance / R) +
          math.cos(lat1) * math.sin(stepDistance / R) * math.cos(angle));

      final lng2 = lng1 +
          math.atan2(
              math.sin(angle) * math.sin(stepDistance / R) * math.cos(lat1),
              math.cos(stepDistance / R) - math.sin(lat1) * math.sin(lat2));

      final newPoint = LatLng(
        lat2 * 180 / math.pi,
        lng2 * 180 / math.pi,
      );

      // Calculate actual distance to new point
      final distanceToNew = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );

      // Calculate distance from new point to start
      final newPointToStart = Geolocator.distanceBetween(
        newPoint.latitude,
        newPoint.longitude,
        startPoint.latitude,
        startPoint.longitude,
      );

      // Only add the point if:
      // 1. The step distance is within our limit
      // 2. Adding this point and returning to start won't exceed max distance
      if (distanceToNew <= maxStepDistance &&
          totalDistance + distanceToNew + newPointToStart <= maxDistance) {
        points.add(newPoint);
        totalDistance += distanceToNew;
      } else {
        // If we can't add this point, try to connect back to start
        if (totalDistance + distanceToStart <= maxDistance) {
          points.add(startPoint);
        }
        break;
      }
    }

    // If we haven't connected back to start yet and we can do it within the limit
    if (points.last != startPoint) {
      final finalDistanceToStart = Geolocator.distanceBetween(
        points.last.latitude,
        points.last.longitude,
        startPoint.latitude,
        startPoint.longitude,
      );

      if (totalDistance + finalDistanceToStart <= maxDistance) {
        points.add(startPoint);
      }
    }

    _addPointsToMap(points);
  }

  // Add new method for getting drawing suggestions
  Future<void> _getDrawingSuggestion() async {
    if (_model == null) {
      print('Model not initialized');
      return;
    }

    setState(() {
      _isGettingSuggestion = true;
    });

    try {
      // Add random seed to prevent caching
      final random = math.Random();
      final categories = [
        'animal',
        'object',
        'character',
        'vehicle',
        'food',
        'plant'
      ];
      final selectedCategory = categories[random.nextInt(categories.length)];

      final prompt =
          '''Suggest a creative ${selectedCategory} to draw on a map. Requirements:
1. Must be a single word or short phrase (a sentence long max)
2. Should be something recognizable when drawn on a map
3. Must be different from: kite, butterfly, cat, house, or stick figure
4. Keep it family-friendly and fun
5. Be creative and unexpected - ${random.nextInt(10000)} (random seed to prevent caching)

Return ONLY the suggestion without any additional text or formatting.''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      if (response.text != null) {
        // Show suggestion in a dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Drawing Suggestion'),
              content: Text(response.text!.trim()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _getDrawingSuggestion();
                  },
                  child: const Text('Suggest something else!'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting drawing suggestion: $e');
    } finally {
      setState(() {
        _isGettingSuggestion = false;
      });
    }
  }

  void _startDrawing() {
    // If there's a current drawing, save it as completed
    if (_currentDrawingPoints.isNotEmpty) {
      _addPointsToMap(_currentDrawingPoints, isCompleted: true);
    }

    setState(() {
      _isManualDrawing = true;
      _currentDrawingPoints = [];
    });

    // Start listening to location updates
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      if (_isManualDrawing) {
        setState(() {
          final newPoint = LatLng(position.latitude, position.longitude);
          if (_currentDrawingPoints.isEmpty || newPoint != _currentDrawingPoints.last) {
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
        // Save the current drawing as completed without connecting back to start
        _addPointsToMap(_currentDrawingPoints, isCompleted: true);
        _currentDrawingPoints = [];
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk and Draw'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
          ElevatedButton(
            onPressed: _isManualDrawing ? _stopDrawing : _startDrawing,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isManualDrawing ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(_isManualDrawing ? 'Stop Drawing' : 'Start Drawing'),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'drawing_suggestion',
                    child: Row(
                      children: [
                        if (_isGettingSuggestion)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black87),
                              ),
                            ),
                          ),
                        const Text('Suggest drawing'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ai_draw',
                    child: Row(
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black87),
                              ),
                            ),
                          ),
                        Text(_isLoading ? 'Generating...' : 'AI Drawing'),
                      ],
                    ),
                  ),
                  if (_polylines.isNotEmpty)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            _isDrawingVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(_isDrawingVisible
                              ? 'Hide AI Drawing'
                              : 'Show AI Drawing'),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'toggle') {
                    setState(() {
                      _isDrawingVisible = !_isDrawingVisible;
                    });
                  } else if (value == 'ai_draw' && !_isLoading) {
                    _requestDrawingSuggestion();
                  } else if (value == 'drawing_suggestion' &&
                      !_isGettingSuggestion) {
                    _getDrawingSuggestion();
                  }
                },
              ),
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
        ],
      ),
    );
  }
}
