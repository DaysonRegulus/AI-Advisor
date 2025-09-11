// lib/providers/food_timeline_provider.dart
import 'package:flutter/material.dart';
import '../models/food_log.dart';
import '../api/api_service.dart';
import '../locator.dart';

class FoodTimelineProvider with ChangeNotifier {
  // Get the ApiService instance from the locator.
  final ApiService _apiService = locator<ApiService>();
  List<FoodLog> _foodLogs = [];
  bool _isLoading = false;

  List<FoodLog> get foodLogs => _foodLogs;
  bool get isLoading => _isLoading;

  Future<void> fetchTodaysFoodLog() async {
    _isLoading = true;
    notifyListeners();
    try {
      _foodLogs = await _apiService.getTodaysFoodLogs();
      // Sort logs by time for correct display
      _foodLogs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      print("Error fetching food timeline: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  // Optimistically add a new log to the UI
  void addFoodLog(FoodLog log) {
    _foodLogs.add(log);
    _foodLogs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }
}