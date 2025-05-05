import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class DrawingSuggestion extends PopupMenuEntry<String> {
  const DrawingSuggestion({super.key});

  @override
  State<DrawingSuggestion> createState() => _DrawingSuggestionState();

  @override
  double get height => 48.0;

  @override
  bool represents(String? value) => value == 'drawing_suggestion';
}

class _DrawingSuggestionState extends State<DrawingSuggestion> {
  bool _isLoading = false;

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
        final suggestion = responseData['response'] as String;
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Drawing Suggestion'),
              content: Text(suggestion.trim()),
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
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuItem(
      value: 'drawing_suggestion',
      onTap: _getDrawingSuggestion,
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              ),
            ),
          Text(_isLoading ? 'Loading...' : 'AI suggestion'),
        ],
      ),
    );
  }
}
