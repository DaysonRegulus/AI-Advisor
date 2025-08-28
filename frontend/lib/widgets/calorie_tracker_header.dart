// lib/widgets/calorie_tracker_header.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../providers/dashboard_provider.dart';
import '../providers/goal_provider.dart';

class CalorieTrackerHeader extends StatelessWidget {
  const CalorieTrackerHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);

    final calorieGoal = goalProvider.userGoals?.dailyCalorieGoal ?? 2000;
    final currentCalories = dashboardProvider.todaysCalorieIntake;
    final double percentage = calorieGoal > 0 ? (currentCalories / calorieGoal) * 100 : 0;
    
    // Change color as the user approaches their goal
    final progressBarColor = percentage > 100 ? Colors.red : Colors.orange;

    return SleekCircularSlider(
      appearance: CircularSliderAppearance(
        size: 150, // Larger than the water tracker
        angleRange: 180, // Make it a semi-circle
        startAngle: 180,
        customWidths: CustomSliderWidths(progressBarWidth: 10, trackWidth: 10),
        customColors: CustomSliderColors(
          trackColor: Colors.grey[200],
          progressBarColor: progressBarColor,
        ),
        infoProperties: InfoProperties(
          mainLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          bottomLabelText: "Kcal",
          bottomLabelStyle: const TextStyle(color: Colors.grey),
          modifier: (value) => currentCalories.toString(),
        ),
      ),
      min: 0,
      max: 100,
      initialValue: percentage,
    );
  }
}