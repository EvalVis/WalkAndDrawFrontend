import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VoteButton extends StatelessWidget {
  final String drawingId;
  final String voterEmail;
  final int voteCount;
  final bool hasVoted;
  final Function(String) onVoteSuccess;

  const VoteButton({
    super.key,
    required this.drawingId,
    required this.voterEmail,
    required this.voteCount,
    required this.hasVoted,
    required this.onVoteSuccess,
  });

  Future<void> _voteForDrawing(BuildContext context) async {
    if (hasVoted) {
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
          'voterEmail': voterEmail,
        }),
      );

      if (response.statusCode == 200) {
        onVoteSuccess(drawingId);

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

  @override
  Widget build(BuildContext context) {
    return Row(
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
            color: hasVoted ? Colors.blue : Colors.grey,
          ),
          onPressed: () => _voteForDrawing(context),
        ),
      ],
    );
  }
}
