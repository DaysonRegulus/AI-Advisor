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
import '../models/user_goals.dart';
import '../models/weight_log.dart';
import '../models/water_log.dart';
import '../models/food_log.dart';
import '../models/dashboard_data.dart';
import '../models/nutrient_breakdown.dart';
import '../models/chart_data_point.dart';

class AgentTimelineItem {
  final String itemType;
  final String? userMessage;
  final String? aiResponse;
  final String? entryId;
  final String? journalContent;

  AgentTimelineItem({
    required this.itemType,
    this.userMessage,
    this.aiResponse,
    this.entryId,
    this.journalContent,
  });

  factory AgentTimelineItem.fromJson(Map<String, dynamic> json) {
    return AgentTimelineItem(
      itemType: json['item_type'],
      userMessage: json['user_message'],
      aiResponse: json['ai_response'],
      entryId: json['entry_id'],
      journalContent: json['journal_content'],
    );
  }
}

class ApiService {
  // IMPORTANT: Use this IP for the Android Emulator to connect to your local machine.
  // For iOS Simulator, you would use 'http://localhost:8000'.
  static const String _baseUrl = '${AppConfig.baseUrl}/api';

  // For testing, we need a hardcoded user ID.
  // Later, this will come from a login/auth process.
  static const String _testUserId = AppConfig.testUserId;

  // --- Implementation of the new methods ---

  Future<FoodLog?> logFood({
    required String foodName,
    required String mealType,
    required double calories,
    String? servingSize,
    Map<String, double>? macros,
    Map<String, double>? micros,
  }) async {
    final url = Uri.parse('$_baseUrl/trackers/log-food');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _testUserId,
          'food_name': foodName,
          'meal_type': mealType,
          'serving_size': servingSize,
          'calories': calories,
          'macros': macros,
          'micros': micros,
        }),
      );

      if (response.statusCode == 201) {
        return FoodLog.fromJson(jsonDecode(response.body));
      } else {
        // Try to parse a more specific error message from the backend
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to save food log.');
      }
    } catch (e) {
      if (e is ApiException) rethrow; // Don't re-wrap our custom exceptions
      throw ApiException('Could not connect to the server to save food log.');
    }
  }

  Future<UserGoals?> getUserGoals() async {
    final url = Uri.parse('$_baseUrl/trackers/goals/$_testUserId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return UserGoals.fromJson(jsonDecode(response.body));
      }
      return null; // A user might not have goals set yet
    } catch (e) {
      print("Error fetching user goals: $e");
      return null;
    }
  }

  Future<DashboardData?> getDashboardData() async {
    final url = Uri.parse('$_baseUrl/trackers/dashboard/$_testUserId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return DashboardData.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      throw ApiException('Could not load dashboard data.');
    }
  }

  Future<void> logWater(int amountMl) async {
    final url = Uri.parse('$_baseUrl/trackers/log-water');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _testUserId, 'amount_ml': amountMl}),
      );
      if (response.statusCode != 201) {
        throw ApiException('Failed to log water intake.');
      }
    } catch (e) {
      throw ApiException('Could not connect to server to log water.');
    }
  }

  // Log weight now returns the created log to update the UI instantly
  Future<WeightLog?> logWeight(double weightKg) async {
    final url = Uri.parse('$_baseUrl/trackers/log-weight');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _testUserId, 'weight_kg': weightKg}),
      );
      if(response.statusCode == 201) {
        // Parse the real object returned from the server
        return WeightLog.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      throw ApiException('Could not save weight log.');
    }
  }
  
  Future<List<WaterLog>> getTodaysWaterLogs() async {
    final url = Uri.parse('$_baseUrl/trackers/water/today/$_testUserId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => WaterLog.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<FoodLog>> getTodaysFoodLogs() async {
        final url = Uri.parse('$_baseUrl/trackers/food/today/$_testUserId');
        try {
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final List<dynamic> data = jsonDecode(response.body);
            return data.map((json) => FoodLog.fromJson(json)).toList();
          }
          // Return an empty list on failure, which is a safe default
          return [];
        } catch (e) {
          print('Error fetching today\'s food logs: $e');
          // Re-throw as a custom exception if you have more granular error handling on the UI
          throw ApiException('Could not fetch food log. Please check your network.');
        }
      }
  
  Future<List<WeightLog>> getWeightHistory() async {
    final url = Uri.parse('$_baseUrl/trackers/weight/history/$_testUserId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => WeightLog.fromJson(json)).toList();
    }
    return [];
  }

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

  // --- Paginated Agent Timeline Fetcher ---
  Future<List<AgentTimelineItem>> fetchAgentTimelinePage(String agentName, int page, {int pageSize = 20}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/ai/timeline/$agentName?user_id=${AppConfig.testUserId}&page=$page&page_size=$pageSize');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AgentTimelineItem.fromJson(json)).toList();
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to load agent timeline');
      }
    } catch (e) {
      throw ApiException('Network error fetching agent timeline: $e');
    }
  }

  // --- Fetch Daily Nutrient Breakdown ---
  Future<NutrientBreakdown?> getDailyNutrientBreakdown() async {
    final url = Uri.parse('$_baseUrl/trackers/calories/daily-breakdown/$_testUserId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return NutrientBreakdown.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      throw ApiException('Could not load calorie breakdown.');
    }
  }

  // --- Fetch Weight Chart History ---
  Future<List<ChartDataPoint>> getWeightChartHistory({int days = 7}) async {
    final url = Uri.parse('$_baseUrl/trackers/weight/chart-history?user_id=$_testUserId&period_days=$days');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChartDataPoint.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw ApiException('Could not load weight chart data.');
    }
  }
}