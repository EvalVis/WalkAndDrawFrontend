import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'drawing_record.dart';

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

  // Selected team and its drawings
  Team? selectedTeam;
  List<Map<String, dynamic>> teamDrawings = [];
  bool loadingDrawings = false;

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

  Future<void> _loadTeamDrawings(String teamId) async {
    setState(() {
      loadingDrawings = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://us-central1-walkanddraw-459410.cloudfunctions.net/getTeamDrawings?teamId=$teamId',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          teamDrawings = data.cast<Map<String, dynamic>>();
          loadingDrawings = false;
        });
      } else {
        setState(() {
          teamDrawings = [];
          loadingDrawings = false;
        });
      }
    } catch (e) {
      setState(() {
        teamDrawings = [];
        loadingDrawings = false;
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

  void _selectTeam(Team team) {
    setState(() {
      selectedTeam = team;
    });
    _loadTeamDrawings(team.id);
  }

  void _goBackToTeamList() {
    setState(() {
      selectedTeam = null;
      teamDrawings = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (selectedTeam != null) {
      return _buildTeamDrawingsScreen();
    }

    return _buildTeamsListScreen();
  }

  Widget _buildTeamsListScreen() {
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
                              child: ListTile(
                                title: Text(teams[index].name),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () => _selectTeam(teams[index]),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDrawingsScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedTeam!.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToTeamList,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Team Drawings',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: loadingDrawings
                  ? const Center(child: CircularProgressIndicator())
                  : teamDrawings.isEmpty
                      ? const Center(
                          child: Text('No drawings shared with this team yet'),
                        )
                      : ListView.builder(
                          itemCount: teamDrawings.length,
                          itemBuilder: (context, index) {
                            final drawing = teamDrawings[index];
                            return DrawingRecord(
                              drawing: drawing,
                              voterEmail: widget.user.email,
                              hasVoted:
                                  false, // You might need to track voted drawings
                              onVoteSuccess: (_) {}, // Handle voting if needed
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
