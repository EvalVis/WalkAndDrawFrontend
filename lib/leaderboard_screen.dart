import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'dart:async';

class LeaderboardScreen extends StatefulWidget {
  final mongo.Db? mongodb;

  const LeaderboardScreen({
    super.key,
    required this.mongodb,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaderboardData = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
    _startPeriodicUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadLeaderboardData();
    });
  }

  Future<void> _loadLeaderboardData() async {
    if (widget.mongodb == null) return;

    try {
      final collection = widget.mongodb!.collection('Ink');
      final cursor = await collection.find(
        mongo.where.sortBy('distance', descending: true),
      );

      final List<Map<String, dynamic>> data = await cursor.toList();
      setState(() {
        _leaderboardData = data;
      });
    } catch (e) {
      print('Error loading leaderboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
      ),
      body: _leaderboardData.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView.builder(
              itemCount: _leaderboardData.length,
              itemBuilder: (context, index) {
                final user = _leaderboardData[index];
                final distance = (user['distance'] as num).toDouble();
                final rank = index + 1;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rank <= 3 ? Colors.amber : Colors.blue,
                    child: Text(
                      rank.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user['username'] ?? 'Anonymous',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${(distance / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                      color: Colors.green,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
