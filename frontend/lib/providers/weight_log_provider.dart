// lib/providers/weight_log_provider.dart
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/chart_data_point.dart';

enum ChartPeriod { sevenDays, thirtyDays }

class WeightLogProvider with ChangeNotifier {
  final ApiService _apiService;
  WeightLogProvider(this._apiService);

  List<ChartDataPoint> _chartData = [];
  bool _isLoading = false;
  ChartPeriod _selectedPeriod = ChartPeriod.sevenDays;

  List<ChartDataPoint> get chartData => _chartData;
  bool get isLoading => _isLoading;
  ChartPeriod get selectedPeriod => _selectedPeriod;

  Future<void> fetchChartData({ChartPeriod period = ChartPeriod.sevenDays}) async {
    _selectedPeriod = period;
    _isLoading = true;
    notifyListeners();
    
    try {
      final days = period == ChartPeriod.sevenDays ? 7 : 30;
      _chartData = await _apiService.getWeightChartHistory(days: days);
    } catch(e) {
      print("Error fetching weight chart data: $e");
      _chartData = []; // Clear data on error
    }
    
    _isLoading = false;
    notifyListeners();
  }
}