// lib/api/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import '../config.dart';
// Models
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

// --- MODELS MOVED FROM TOP OF FILE FOR CLARITY ---

class AuthTokenResponse {
  final String accessToken;
  final String refreshToken;
  AuthTokenResponse({required this.accessToken, required this.refreshToken});
  factory AuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return AuthTokenResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}

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
  static const String _baseUrl = '${AppConfig.baseUrl}/api';

  final http.Client _client;
  ApiService(this._client); // Constructor

  // --- Authentication Methods (Unprotected) ---

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/signup');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to sign up.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the server to sign up.');
    }
  }

  Future<AuthTokenResponse> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        return AuthTokenResponse.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to log in.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the server to log in.');
    }
  }

  // --- ALL SUBSEQUENT METHODS ARE NOW PROTECTED ---

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
      final response = await _client.post(
        url,
        // headers are now handled by the interceptor
        body: jsonEncode({
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
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to save food log.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the server to save food log.');
    }
  }
  
  // Note the pattern: Every method now uses `headers: _getHeaders()` and has
  // no `user_id` in the URL or body. I will apply this to all methods.

  Future<UserGoals?> getUserGoals() async {
    final url = Uri.parse('$_baseUrl/trackers/goals');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return UserGoals.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print("Error fetching user goals: $e");
      return null;
    }
  }

  Future<DashboardData?> getDashboardData() async {
    final url = Uri.parse('$_baseUrl/trackers/dashboard');
    try {
      final response = await _client.get(url);
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
      final response = await _client.post(
        url,
        // headers are now handled by the interceptor
        body: jsonEncode({'amount_ml': amountMl}),
      );
      if (response.statusCode != 201) {
        throw ApiException('Failed to log water intake.');
      }
    } catch (e) {
      throw ApiException('Could not connect to server to log water.');
    }
  }

  Future<WeightLog?> logWeight(double weightKg) async {
    final url = Uri.parse('$_baseUrl/trackers/log-weight');
    try {
      final response = await _client.post(
        url,
        // headers are now handled by the interceptor
        body: jsonEncode({'weight_kg': weightKg}),
      );
      if(response.statusCode == 201) {
        return WeightLog.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      throw ApiException('Could not save weight log.');
    }
  }
  
  Future<List<WaterLog>> getTodaysWaterLogs() async {
    final url = Uri.parse('$_baseUrl/trackers/water/today');
    final response = await _client.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => WaterLog.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<FoodLog>> getTodaysFoodLogs() async {
    final url = Uri.parse('$_baseUrl/trackers/food/today');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => FoodLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw ApiException('Could not fetch food log.');
    }
  }
  
  Future<List<WeightLog>> getWeightHistory() async {
    final url = Uri.parse('$_baseUrl/trackers/weight/history');
    final response = await _client.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => WeightLog.fromJson(json)).toList();
    }
    return [];
  }

  Future<String> interactWithAi(String agentName, String message) async {
    final url = Uri.parse('$_baseUrl/ai/interact');
    try {
      final response = await _client.post(
        url,
        // headers are now handled by the interceptor
        body: jsonEncode({
          'agent_name': agentName,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'AI agent unavailable.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the AI service.');
    }
  }

  Future<UserProfile?> fetchUserProfile() async {
    final url = Uri.parse('$_baseUrl/user/profile');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['error'] ?? 'Unknown API error');
      }
    } catch (e) {
      throw ApiException('Could not connect to the server.');
    }
  }
  
  // --- Award XP Method ---
  Future<UserProfile?> awardXp(String eventName, int amount) async {
    final url = Uri.parse('$_baseUrl/user/award-xp');
    print('Calling API: $url to award $amount XP for $eventName');

    try {
       final response = await _client.post(
        url,
        // headers are now handled by the interceptor
        body: jsonEncode({
          // No user_id needed in the body anymore
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

  Future<void> generateDailySummary() async {
    final url = Uri.parse('$_baseUrl/overseer/generate-summary');
    try {
      // This is a POST request with an empty body
      final response = await _client.post(url);
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to generate summary.');
      }
    } catch(e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the AI service.');
    }
  }

  Future<DailySummary?> fetchDailySummary() async {
    final url = Uri.parse('$_baseUrl/overseer/latest-summary');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return DailySummary.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to fetch summary.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the AI service.');
    }
  }


  Future<JournalEntry?> addJournalEntry(String content) async {
    final url = Uri.parse('$_baseUrl/journal/add');
    try {
      final response = await _client.post(
        url,
        // headers are now handled by the interceptor
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201) {
        return JournalEntry.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Failed to save entry.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to the server to save entry.');
    }
  }

  Future<List<AIComment>> getJournalComments(String entryId) async {
    // This endpoint is not used, timeline is better.
    // But if it were, it would need headers.
    throw UnimplementedError();
  }

  Future<List<JournalTimelineItem>> fetchTimelinePage(int page, {int pageSize = 20}) async {
    final url = Uri.parse('$_baseUrl/journal/timeline?page=$page&page_size=$pageSize');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) {
          if (json['item_type'] == 'journal_entry') {
            return JournalEntry.fromJson(json);
          } else {
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

  Future<List<AgentTimelineItem>> fetchAgentTimelinePage(String agentName, int page, {int pageSize = 20}) async {
    final url = Uri.parse('$_baseUrl/ai/timeline/$agentName?page=$page&page_size=$pageSize');
    try {
      final response = await _client.get(url);
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

  Future<NutrientBreakdown?> getDailyNutrientBreakdown() async {
    final url = Uri.parse('$_baseUrl/trackers/calories/daily-breakdown');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return NutrientBreakdown.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      throw ApiException('Could not load calorie breakdown.');
    }
  }

  Future<List<ChartDataPoint>> getWeightChartHistory({int days = 7}) async {
    final url = Uri.parse('$_baseUrl/trackers/weight/chart-history?period_days=$days');
    try {
      final response = await _client.get(url);
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