// lib/providers/goal_provider.dart
import 'package:flutter/material.dart';
import '../models/user_goals.dart';
import '../api/api_service.dart';
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
    } catch (e) {
      print("Error fetching goals: $e");
    }
    _isLoading = false;
    notifyListeners();
  }
  
  // We will add a method to update goals later when we build the settings screen.
}