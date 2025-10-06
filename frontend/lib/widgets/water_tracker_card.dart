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
import '../locator.dart';

class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);

    final waterGoal = goalProvider.userGoals?.dailyWaterGoalMl ?? 2500;
    final currentIntake = dashboardProvider.todaysWaterIntake;
    
    final double percentage = waterGoal > 0 ? (currentIntake / waterGoal) * 100 : 0;
    
    // Get the singleton instance from our service locator.
    final apiService = locator<ApiService>();

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Water Intake", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text("$currentIntake / $waterGoal ml", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.blue, size: 30),
                    onPressed: () async {
                      // Note: We should add a feature to undo a specific log later.
                      // For now, this just logs a negative value if needed.
                      const amount = -250; 
                      await apiService.logWater(amount);
                      dashboardProvider.addWater(amount);
                      // Awarding XP for removing water might not be desired, but we'll leave it for now.
                      Provider.of<UserProfileProvider>(context, listen: false).awardXpForEvent('water_log', 5);
                      // This global refresh can be intensive. A more targeted update is better.
                      // For now, it ensures consistency.
                      await context.read<RefreshProvider>().refreshAllData!();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                    onPressed: () async {
                      const amount = 250;
                      await apiService.logWater(amount);
                      dashboardProvider.addWater(amount);
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