// lib/providers/dashboard_provider.dart
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/weight_log.dart';

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  int _todaysWaterIntake = 0;
  int _todaysCalorieIntake = 0;
  WeightLog? _latestWeightLog;
  bool _isLoading = false;

  int get todaysWaterIntake => _todaysWaterIntake;
  int get todaysCalorieIntake => _todaysCalorieIntake;
  WeightLog? get latestWeightLog => _latestWeightLog;
  bool get isLoading => _isLoading;
  
  Future<void> fetchDashboardData() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Call the single, efficient API endpoint
      final dashboardData = await _apiService.getDashboardData();
      if (dashboardData != null) {
        _todaysWaterIntake = dashboardData.todaysWaterIntake;
        _todaysCalorieIntake = dashboardData.todaysCalorieIntake;
        _latestWeightLog = dashboardData.latestWeightLog;
      }
    } catch (e) {
      print("Error fetching dashboard data: $e");
      // You can set an error state here for the UI
    }
    _isLoading = false;
    notifyListeners();
  }

  // Methods to update state after logging new data, so we don't have to re-fetch everything.
  void addWater(int amountMl) {
    _todaysWaterIntake += amountMl;
    notifyListeners();
  }
  
  void logNewWeight(WeightLog newLog) {
    _latestWeightLog = newLog;
    notifyListeners();
  }
}