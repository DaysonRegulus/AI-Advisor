// lib/providers/calorie_provider.dart
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/nutrient_breakdown.dart';
import '../locator.dart';

class CalorieProvider with ChangeNotifier {
  final ApiService _apiService = locator<ApiService>();

  // The constructor is now empty
  CalorieProvider();

  NutrientBreakdown? _breakdown;
  bool _isLoading = false;

  NutrientBreakdown? get breakdown => _breakdown;
  bool get isLoading => _isLoading;

  Future<void> fetchBreakdown() async {
    _isLoading = true;
    notifyListeners();
    try {
      _breakdown = await _apiService.getDailyNutrientBreakdown();
    } catch(e) {
      print("Error fetching nutrient breakdown: $e");
    }
    _isLoading = false;
    notifyListeners();
  }
}