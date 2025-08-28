// lib/models/dashboard_data.dart
import 'weight_log.dart';

class DashboardData {
  final int todaysWaterIntake;
  final int todaysCalorieIntake;
  final WeightLog? latestWeightLog;

  DashboardData({
    required this.todaysWaterIntake,
    required this.todaysCalorieIntake,
    this.latestWeightLog,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      todaysWaterIntake: (json['todays_water_intake'] as num).toInt(),
      todaysCalorieIntake: (json['todays_calorie_intake'] as num).toInt(),
      latestWeightLog: json['latest_weight_log'] != null
          ? WeightLog.fromJson(json['latest_weight_log'])
          : null,
    );
  }
}