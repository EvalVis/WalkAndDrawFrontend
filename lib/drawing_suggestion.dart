import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class DrawingSuggestion extends StatefulWidget {
  const DrawingSuggestion({super.key});

  @override
  State<DrawingSuggestion> createState() => _DrawingSuggestionState();
}

class _DrawingSuggestionState extends State<DrawingSuggestion> {
  bool _isLoading = false;
  String? _suggestion;

  @override
  void initState() {
    super.initState();
    _getDrawingSuggestion();
  }

  Future<void> _getDrawingSuggestion() async {
    setState(() {
      _isLoading = true;
    });

    try {
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
5. Be creative and unexpected - ${random.nextInt(10000)}

Return ONLY the suggestion without any additional text or formatting.''';

      final response = await http.post(
        Uri.parse(
            'https://us-central1-walkanddraw.cloudfunctions.net/callGemini'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': prompt}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _suggestion = responseData['response'] as String;
        });
      }
    } catch (e) {
      print('Error getting drawing suggestion: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Drawing Suggestion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_suggestion != null)
            Text(_suggestion!.trim())
          else
            const Text('Karate cat'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _getDrawingSuggestion,
          child: const Text('Suggest something else!'),
        ),
      ],
    );
  }
}
