// lib/api/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/daily_summary.dart';

class ApiService {
  // IMPORTANT: Use this IP for the Android Emulator to connect to your local machine.
  // For iOS Simulator, you would use 'http://localhost:8000'.
  static const String _baseUrl = 'http://10.0.2.2:8000/api';

  // For testing, we need a hardcoded user ID.
  // Later, this will come from a login/auth process.
  static const String _testUserId = "cea64e5e-ff2d-4096-970f-2d23d3429eb5"; // <--- PASTE YOUR TEST USER ID

  // --- AI Interaction Method ---
  Future<String> interactWithAi(String agentName, String message) async {
    final url = Uri.parse('$_baseUrl/ai/interact');
    print('Calling API: $url with agent: $agentName');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'agent_name': agentName,
          'message': message,
          'user_id': _testUserId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Response: ${data['response']}');
        return data['response'];
      } else {
        print('API Error: ${response.statusCode} ${response.body}');
        return "Error: Could not connect to the AI agent. ${response.body}";
      }
    } catch (e) {
      print('Network Error: $e');
      return "Network Error: Could not reach the server. Is it running?";
    }
  }

  // --- Fetch User Profile Method ---
  Future<UserProfile?> fetchUserProfile() async {
    final url = Uri.parse('$_baseUrl/user/profile/$_testUserId');
    print('Calling API to fetch user profile...');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('User profile fetched successfully.');
        return UserProfile.fromJson(data);
      } else {
        print('API Error fetching profile: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Network error fetching profile: $e');
      return null;
    }
  }

  // --- Award XP Method ---
  Future<UserProfile?> awardXp(String eventName, int amount) async {
    final url = Uri.parse('$_baseUrl/user/award-xp');
    print('Calling API: $url to award $amount XP for $eventName');

    try {
       final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _testUserId,
          'amount': amount,
          'event_name': eventName
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('XP Awarded. New profile: $data');
        return UserProfile.fromJson(data);
      } else {
        print('API Error awarding XP: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch(e) {
      print('Network Error awarding XP: $e');
      return null;
    }
  }

  // --- Generate Daily Summary Method ---
  Future<void> generateDailySummary() async {
    final url = Uri.parse('$_baseUrl/overseer/generate-summary');
    print('Calling API to generate daily summary...');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _testUserId}),
      );
      if (response.statusCode == 200) {
        print('Summary generation successful.');
      } else {
        // We throw an error so the provider can catch it.
        print('API Error generating summary: ${response.statusCode} ${response.body}');
        throw 'Failed to generate summary: ${response.body}';
      }
    } catch(e) {
      print('Network error generating summary: $e');
      throw 'Network error. Could not reach server.';
    }
  }

  // --- Fetch Latest Daily Summary Method ---
  Future<DailySummary?> fetchDailySummary() async {
    // To do this properly, we need a new GET endpoint on the backend.
    // Let's add it to overseer_router.py right now.
    final url = Uri.parse('$_baseUrl/overseer/latest-summary/$_testUserId');
    print('Calling API to fetch latest summary...');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Summary fetched successfully.');
        return DailySummary.fromJson(data);
      } else if (response.statusCode == 404) {
        print('No summary found for today.');
        return null;
      }
       else {
        print('API Error fetching summary: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Network error fetching summary: $e');
      return null;
    }
  }

  // --- Add Journal Entry Method ---
  Future<bool> addJournalEntry(String content) async {
    final url = Uri.parse('$_baseUrl/journal/add');
    print('Calling API to add journal entry...');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _testUserId,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        print('Journal entry added successfully.');
        return true;
      } else {
        print('API Error adding journal entry: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Network error adding journal entry: $e');
      return false;
    }
  }
}