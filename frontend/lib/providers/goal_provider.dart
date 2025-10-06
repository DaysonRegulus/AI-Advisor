// lib/providers/goal_provider.dart
import 'package:flutter/material.dart';
import '../models/user_goals.dart';
import '../api/api_service.dart';
import '../api/api_exception.dart';
import '../locator.dart';

class GoalProvider with ChangeNotifier {
  // Get the ApiService instance from the locator.
  final ApiService _apiService = locator<ApiService>();
  UserGoals? _userGoals;
  bool _isLoading = false;

  UserGoals? get userGoals => _userGoals;
  bool get isLoading => _isLoading;

  Future<void> fetchGoals() async {
    _isLoading = true;
    notifyListeners();
    try {
      _userGoals = await _apiService.getUserGoals();
    } on ApiException catch (e) {
      // If the API throws our custom exception, we check if it's
      // because the goals were not found. In that case, we simply set
      // goals to null and don't treat it as a critical error.
      if (e.message.contains("User goals not found")) {
        print("GoalProvider: No goals found for user. Setting to null.");
        _userGoals = null;
      } else {
        // For any other API error, we should probably log it.
        print("GoalProvider: An API error occurred fetching goals: $e");
        _userGoals = null; // Also clear goals on other errors
      }
    } catch (e) {
      // Catch any other unexpected errors (e.g., network issues)
      print("Error fetching goals: $e");
      _userGoals = null;
    }
    _isLoading = false;
    notifyListeners();
  }
  
  // We will add a method to update goals later when we build the settings screen.
}