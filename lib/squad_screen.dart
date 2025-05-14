import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SquadScreen extends StatefulWidget {
  final GoogleSignInAccount user;

  const SquadScreen({
    super.key,
    required this.user,
  });

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  List<Team> teams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://us-central1-walkanddraw-459410.cloudfunctions.net/getTeams?email=${widget.user.email}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          teams = data.map((team) => Team.fromJson(team)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createTeam(String teamName) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://us-central1-walkanddraw-459410.cloudfunctions.net/createTeam'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'teamName': teamName, 'email': widget.user.email}),
      );

      if (response.statusCode == 200) {
        _loadTeams();
      }
    } catch (e) {
      // Error handling if needed
    }
  }

  void _showCreateTeamDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Squad'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Squad name',
            hintText: 'Enter your squad name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createTeam(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create a new squad'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your teams',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : teams.isEmpty
                      ? const Center(
                          child: Text('You haven\'t joined any teams yet'),
                        )
                      : ListView.builder(
                          itemCount: teams.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(title: Text(teams[index].name)),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
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
