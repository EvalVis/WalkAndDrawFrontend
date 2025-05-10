import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'drawing_record.dart';

enum SortOption { recent, mostVoted }

class DrawingsScreen extends StatefulWidget {
  final GoogleSignInAccount user;

  const DrawingsScreen({super.key, required this.user});

  @override
  State<DrawingsScreen> createState() => _DrawingsScreenState();
}

class _DrawingsScreenState extends State<DrawingsScreen> {
  List<Map<String, dynamic>> _drawings = [];
  bool _isLoading = true;
  String? _error;
  Set<String> _votedDrawings = {};
  SortOption _currentSort = SortOption.recent;

  @override
  void initState() {
    super.initState();
    _fetchDrawings();
  }

  @override
  void dispose() {
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
          'https://us-central1-walkanddraw-459410.cloudfunctions.net/getDrawingsSorted?sortBy=$sortBy',
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

  Future<void> _voteSuccess(String drawingId) async {
    setState(() {
      _votedDrawings.add(drawingId);
      final drawingIndex = _drawings.indexWhere((d) => d['id'] == drawingId);
      if (drawingIndex != -1) {
        _drawings[drawingIndex]['voteCount'] =
            (_drawings[drawingIndex]['voteCount'] ?? 0) + 1;
      }
    });
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
                        return DrawingRecord(
                          drawing: drawing,
                          voterEmail: widget.user.email ?? 'anonymous',
                          hasVoted: _votedDrawings.contains(drawing['id']),
                          onVoteSuccess: _voteSuccess,
                        );
                      },
                    ),
    );
  }
}
