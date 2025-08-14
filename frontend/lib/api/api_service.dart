// lib/api/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import '../config.dart';
import '../models/user_profile.dart';
import '../models/daily_summary.dart';
import '../models/journal_entry.dart';
import '../models/ai_comment.dart';
import '../models/journal_timeline_item.dart';

class ApiService {
  // IMPORTANT: Use this IP for the Android Emulator to connect to your local machine.
  // For iOS Simulator, you would use 'http://localhost:8000'.
  static const String _baseUrl = '${AppConfig.baseUrl}/api';

  // For testing, we need a hardcoded user ID.
  // Later, this will come from a login/auth process.
  static const String _testUserId = AppConfig.testUserId;

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
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'The AI agent is currently unavailable.';
        throw ApiException(errorMessage);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the AI service. Please check your network.');
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
        // Try to parse a structured error message from the backend
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Unknown API error';
        print('API Error fetching profile: ${response.statusCode} $errorMessage');
        throw ApiException('Error: $errorMessage');
      }
      } catch (e) {
        print('Network error fetching profile: $e');
        throw ApiException('Could not connect to the server. Please check your network connection.');
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
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'The AI agent is currently unavailable.';
        throw ApiException(errorMessage);
      }
    } catch(e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the AI service. Please check your network.');
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
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'The AI agent is currently unavailable.';
        throw ApiException(errorMessage);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the AI service. Please check your network.');
    }
  }


  // --- Add Journal Entry Method ---
  Future<JournalEntry?> addJournalEntry(String content) async {
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

      if (response.statusCode == 201) { // We changed the backend to return 201 Created
        print('Journal entry added successfully.');
        return JournalEntry.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Failed to save journal entry.';
        throw ApiException(errorMessage);
      }
    } catch (e) {
      if (e is ApiException) rethrow; // Don't wrap our own exceptions
      throw ApiException('Could not connect to the server to save entry.');
    }
  }

  // --- NEW: Get Comments for an Entry ---
  Future<List<AIComment>> getJournalComments(String entryId) async {
    final url = Uri.parse('$_baseUrl/journal/comments/$entryId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AIComment.fromJson(json)).toList();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Failed to load journal comments.';
        throw ApiException(errorMessage);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the server to get journal comments.');
    }
  }

  // --- NEW: Paginated Timeline Fetcher ---
  Future<List<JournalTimelineItem>> fetchTimelinePage(int page, {int pageSize = 20}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/journal/timeline?user_id=${AppConfig.testUserId}&page=$page&page_size=$pageSize');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // We need to parse the generic items into our specific Dart models
        return data.map((json) {
          if (json['item_type'] == 'journal_entry') {
            return JournalEntry.fromJson(json);
          } else { // 'ai_comment'
            return AIComment.fromJson(json);
          }
        }).toList();
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to load timeline');
      }
    } catch (e) {
      throw ApiException('Network error fetching timeline: $e');
    }
  }
}