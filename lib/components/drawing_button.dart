import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/drawing_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'drawing_map_renderer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum DrawingVisibility {
  public,
  team,
  private,
}

class DrawingButton extends StatefulWidget {
  final GoogleSignInAccount user;
  final Function(ColoredDrawing, bool) onPointsUpdated;
  final Function(Color)? onColorChanged;

  const DrawingButton({
    super.key,
    required this.user,
    required this.onPointsUpdated,
    this.onColorChanged,
  });

  @override
  State<DrawingButton> createState() => _DrawingButtonState();
}

class _DrawingButtonState extends State<DrawingButton> {
  bool _isManualDrawing = false;
  List<ColoredPoint> _currentDrawingPoints = [];
  Position? _lastDrawingPosition;
  double _totalDistance = 0;
  StreamSubscription<Position>? _positionStreamSubscription;
  final DrawingService _drawingService = DrawingService();
  Color _currentColor = Colors.red;
  bool _isDrawingPaused = false;

  Color get currentColor => _currentColor;
  bool get isDrawing => _isManualDrawing;

  void _startDrawing() {
    if (_currentDrawingPoints.isNotEmpty) {
      final completedDrawing = ColoredDrawing(
        points: List.from(_currentDrawingPoints),
      );
      widget.onPointsUpdated(completedDrawing, true);
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
        }
        _lastDrawingPosition = position;

        setState(() {
          final newPoint = ColoredPoint(
            position: LatLng(position.latitude, position.longitude),
            color: _currentColor,
          );

          if (_currentDrawingPoints.isEmpty ||
              newPoint.position != _currentDrawingPoints.last.position) {
            _currentDrawingPoints.add(newPoint);
            final currentDrawing = ColoredDrawing(
              points: List.from(_currentDrawingPoints),
            );
            widget.onPointsUpdated(currentDrawing, false);
          }
        });
      }
    });
  }

  void _stopDrawing() async {
    _positionStreamSubscription?.cancel();

    if (_currentDrawingPoints.isEmpty) {
      setState(() {
        _isManualDrawing = false;
      });
      return;
    }

    final completedDrawing = ColoredDrawing(
      points: List.from(_currentDrawingPoints),
    );
    widget.onPointsUpdated(completedDrawing, true);

    setState(() {
      _isDrawingPaused = true;
    });
  }

  void _resumeDrawing() {
    setState(() {
      _isDrawingPaused = false;
      _isManualDrawing = true;
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
        }
        _lastDrawingPosition = position;

        setState(() {
          final newPoint = ColoredPoint(
            position: LatLng(position.latitude, position.longitude),
            color: _currentColor,
          );

          if (_currentDrawingPoints.isEmpty ||
              newPoint.position != _currentDrawingPoints.last.position) {
            _currentDrawingPoints.add(newPoint);
            final currentDrawing = ColoredDrawing(
              points: List.from(_currentDrawingPoints),
            );
            widget.onPointsUpdated(currentDrawing, false);
          }
        });
      }
    });
  }

  void _showSaveDrawingDialog() {
    showDialog(
      context: context,
      builder: (context) => _SaveDrawingDialog(
        user: widget.user,
        onSave: (visibility, teamIds) async {
          Navigator.pop(context);

          // Always save the drawing publicly if isPublic is true
          if (visibility == DrawingVisibility.public) {
            await _drawingService.saveDrawing(
              points: _currentDrawingPoints,
              email: widget.user.email,
              name: widget.user.displayName,
              distance: _totalDistance,
            );
          }

          // If teamIds is provided, also save to teams (this could happen in addition to public)
          if (teamIds != null) {
            // For now this will not perform any operation
            // TODO: Implement team save logic
            print('Would save to teams: $teamIds');
          }

          setState(() {
            _isManualDrawing = false;
            _isDrawingPaused = false;
            _currentDrawingPoints = [];
            _totalDistance = 0;
          });
        },
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentColor,
            onColorChanged: (color) {
              setState(() => _currentColor = color);
              if (widget.onColorChanged != null) {
                widget.onColorChanged!(color);
              }
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: true,
            displayThumbColor: true,
            paletteType: PaletteType.hsv,
            pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Done'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!_isDrawingPaused)
          ElevatedButton(
            onPressed: _isManualDrawing ? _stopDrawing : _startDrawing,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isManualDrawing ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              minimumSize: _isManualDrawing ? const Size(120, 36) : null,
            ),
            child: Text(_isManualDrawing ? 'Stop Drawing' : 'Start Drawing'),
          ),
        if (_isDrawingPaused)
          Row(
            children: [
              ElevatedButton(
                onPressed: _resumeDrawing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 36),
                ),
                child: const Text('Continue'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _showSaveDrawingDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 36),
                ),
                child: const Text('Finish'),
              ),
            ],
          ),
        if (_isManualDrawing && !_isDrawingPaused)
          GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _SaveDrawingDialog extends StatefulWidget {
  final GoogleSignInAccount user;
  final Function(DrawingVisibility visibility, List<String>? teamIds) onSave;

  const _SaveDrawingDialog({
    Key? key,
    required this.user,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_SaveDrawingDialog> createState() => _SaveDrawingDialogState();
}

class _SaveDrawingDialogState extends State<_SaveDrawingDialog> {
  bool _isPublic = true;
  Set<String> _selectedTeamIds = {};
  List<Team> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://us-central1-walkanddraw-459410.cloudfunctions.net/getTeams?email=${widget.user.email}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Teams loaded: ${data.length}');
        setState(() {
          _teams = data.map((team) => Team.fromJson(team)).toList();
          _isLoading = false;
        });
      } else {
        print('Failed to load teams: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading teams: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Drawing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: const Text('Make drawing public'),
            subtitle: const Text('Everyone can see your drawing'),
            value: _isPublic,
            onChanged: (value) {
              setState(() {
                _isPublic = value ?? true;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          const Text(
            'Share with teams:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _teams.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'You don\'t have any teams yet',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    )
                  : Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _teams.map((team) {
                            return CheckboxListTile(
                              title: Text(team.name),
                              value: _selectedTeamIds.contains(team.id),
                              dense: true,
                              onChanged: (selected) {
                                setState(() {
                                  if (selected ?? false) {
                                    _selectedTeamIds.add(team.id);
                                  } else {
                                    _selectedTeamIds.remove(team.id);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.trailing,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Determine the visibility based on checkboxes
            DrawingVisibility visibility = _isPublic
                ? DrawingVisibility.public
                : DrawingVisibility.private;

            // Pass the list of selected team IDs
            widget.onSave(visibility,
                _selectedTeamIds.isEmpty ? null : _selectedTeamIds.toList());
          },
          child: const Text('Publish Drawing'),
        ),
      ],
    );
  }
}

class Team {
  final String id;
  final String name;
  final String creatorEmail;

  Team({required this.id, required this.name, required this.creatorEmail});

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
        id: json['id'],
        name: json['teamName'],
        creatorEmail: json['creatorEmail']);
  }
}
