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
        onSave: (visibility, teamId) async {
          Navigator.pop(context);

          if (visibility == DrawingVisibility.public) {
            await _drawingService.saveDrawing(
              points: _currentDrawingPoints,
              email: widget.user.email,
              name: widget.user.displayName,
              distance: _totalDistance,
            );
          } else if (visibility == DrawingVisibility.team) {
            // For now this will not perform any operation
            // TODO: Implement team save logic
          } else {
            // For private, no operation for now
            // TODO: Implement private save logic
          }

          setState(() {
            _isManualDrawing = false;
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
  final Function(DrawingVisibility visibility, String? teamId) onSave;

  const _SaveDrawingDialog({
    Key? key,
    required this.user,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_SaveDrawingDialog> createState() => _SaveDrawingDialogState();
}

class _SaveDrawingDialogState extends State<_SaveDrawingDialog> {
  DrawingVisibility _visibility = DrawingVisibility.public;
  String? _selectedTeamId;
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
          'https://us-central1-walkanddraw-7b9ea.cloudfunctions.net/getTeams?email=${widget.user.email}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _teams = data.map((team) => Team.fromJson(team)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
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
          const Text('How would you like to share your drawing?'),
          const SizedBox(height: 16),
          RadioListTile<DrawingVisibility>(
            title: const Text('Public'),
            subtitle: const Text('Everyone can see your drawing'),
            value: DrawingVisibility.public,
            groupValue: _visibility,
            onChanged: (value) {
              setState(() {
                _visibility = value!;
              });
            },
          ),
          RadioListTile<DrawingVisibility>(
            title: const Text('Team'),
            subtitle: const Text('Only your team members can see this drawing'),
            value: DrawingVisibility.team,
            groupValue: _visibility,
            onChanged: (value) {
              setState(() {
                _visibility = value!;
              });
            },
          ),
          if (_visibility == DrawingVisibility.team)
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _teams.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('You don\'t have any teams yet'),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('Select a team'),
                          value: _selectedTeamId,
                          items: _teams.map((team) {
                            return DropdownMenuItem<String>(
                              value: team.id,
                              child: Text(team.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeamId = value;
                            });
                          },
                        ),
                      ),
          RadioListTile<DrawingVisibility>(
            title: const Text('Private'),
            subtitle: const Text('Only you can see this drawing'),
            value: DrawingVisibility.private,
            groupValue: _visibility,
            onChanged: (value) {
              setState(() {
                _visibility = value!;
              });
            },
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
            // Validate that a team is selected when team visibility is chosen
            if (_visibility == DrawingVisibility.team &&
                _selectedTeamId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a team'),
                ),
              );
              return;
            }

            widget.onSave(_visibility, _selectedTeamId);
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
