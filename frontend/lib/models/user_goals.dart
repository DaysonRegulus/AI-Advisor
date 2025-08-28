// lib/models/user_goals.dart

class UserGoals {
  final String userId;
  final int? dailyWaterGoalMl;
  final int? dailyCalorieGoal;
  final double? weightGoalKg;
  final String? weightGoalType; // 'lose', 'gain', 'maintain'

  UserGoals({
    required this.userId,
    this.dailyWaterGoalMl,
    this.dailyCalorieGoal,
    this.weightGoalKg,
    this.weightGoalType,
  });

  factory UserGoals.fromJson(Map<String, dynamic> json) {
    return UserGoals(
      userId: json['user_id'],
      dailyWaterGoalMl: json['daily_water_goal_ml'],
      dailyCalorieGoal: json['daily_calorie_goal'],
      // Convert numeric types carefully
      weightGoalKg: (json['weight_goal_kg'] as num?)?.toDouble(),
      weightGoalType: json['weight_goal_type'],
    );
  }
}