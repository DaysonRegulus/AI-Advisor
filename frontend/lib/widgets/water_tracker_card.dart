// lib/widgets/water_tracker_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../providers/dashboard_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/refresh_provider.dart';
import '../api/api_service.dart';
import '../screens/trackers/water_log_screen.dart';

class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We listen to multiple providers to build this widget
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);

    // Set default goals if none are fetched
    final waterGoal = goalProvider.userGoals?.dailyWaterGoalMl ?? 2500;
    final currentIntake = dashboardProvider.todaysWaterIntake;
    
    // Calculate the percentage, ensuring we don't divide by zero
    final double percentage = waterGoal > 0 ? (currentIntake / waterGoal) * 100 : 0;
    
    final apiService = ApiService(); // Temporary for button actions

    return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WaterLogScreen()),
          );
        },
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Circular Progress Indicator
              SleekCircularSlider(
                appearance: CircularSliderAppearance(
                  size: 80,
                  customWidths: CustomSliderWidths(
                    progressBarWidth: 8,
                    trackWidth: 8,
                    shadowWidth: 10,
                  ),
                  customColors: CustomSliderColors(
                    trackColor: Colors.grey[200],
                    progressBarColor: Colors.blue,
                    shadowColor: Colors.blue[100],
                    shadowMaxOpacity: 0.1,
                  ),
                  infoProperties: InfoProperties(
                    mainLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    modifier: (percentage) => '${percentage.toInt()}%',
                  ),
                ),
                min: 0,
                max: 100,
                initialValue: percentage,
              ),
              // Text Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Water Intake", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text("$currentIntake / $waterGoal ml", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
              // Action Buttons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.blue, size: 30),
                    onPressed: () async {
                      // In a real app, this would be a configurable amount
                      const amount = -250; 
                      await apiService.logWater(amount);
                      dashboardProvider.addWater(amount);
                      Provider.of<UserProfileProvider>(context, listen: false).awardXpForEvent('water_log', 5);
                      await context.read<RefreshProvider>().refreshAllData!();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                    onPressed: () async {
                      const amount = 250; // Assume one glass is 250ml
                      await apiService.logWater(amount);
                      // Optimistically update the UI
                      dashboardProvider.addWater(amount);
                      // Award XP
                      Provider.of<UserProfileProvider>(context, listen: false).awardXpForEvent('water_log', 5);
                      await context.read<RefreshProvider>().refreshAllData!();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      )
    );
  }
}