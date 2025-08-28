// lib/widgets/weight_tracker_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/goal_provider.dart';

class WeightTrackerCard extends StatelessWidget {
  const WeightTrackerCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);

    final latestWeight = dashboardProvider.latestWeightLog?.weightKg;
    final weightGoal = goalProvider.userGoals?.weightGoalKg;
    final goalType = goalProvider.userGoals?.weightGoalType;

    Widget content;

    if (latestWeight == null) {
      // Onboarding state for new users
      content = const Center(
        child: Text("Tap to log your first weight entry!"),
      );
    } else {
      // Main display state
      IconData arrowIcon = Icons.arrow_forward;
      Color arrowColor = Colors.grey;
      String progressText = "No goal set";

      if (weightGoal != null && goalType != null) {
          double progress = (latestWeight - weightGoal).abs();
          progressText = "${progress.toStringAsFixed(1)} kg from goal";

          if (goalType == 'lose') {
              if (latestWeight < weightGoal) { // Surpassed goal
                  arrowIcon = Icons.check_circle;
                  arrowColor = Colors.green;
              } else if (latestWeight > dashboardProvider.latestWeightLog!.weightKg) { // Gaining weight
                  arrowIcon = Icons.arrow_upward;
                  arrowColor = Colors.red;
              } else { // Losing weight
                  arrowIcon = Icons.arrow_downward;
                  arrowColor = Colors.green;
              }
          } else if (goalType == 'gain') {
              if (latestWeight > weightGoal) { // Surpassed goal
                  arrowIcon = Icons.check_circle;
                  arrowColor = Colors.green;
              } else if (latestWeight > dashboardProvider.latestWeightLog!.weightKg) { // Gaining weight
                  arrowIcon = Icons.arrow_upward;
                  arrowColor = Colors.green;
              } else { // Losing weight
                  arrowIcon = Icons.arrow_downward;
                  arrowColor = Colors.red;
              }
          }
      }

      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${latestWeight.toStringAsFixed(1)} kg",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(arrowIcon, color: arrowColor, size: 20),
              const SizedBox(width: 4),
              Text(progressText, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ],
      );
    }

    return Card(
      elevation: 4,
      child: InkWell( // Make the whole card tappable
        onTap: () {
          // TODO: Navigate to the dedicated WeightScreen
          print("Navigate to Weight Screen");
        },
        child: Container(
          height: 120, // Give the card a fixed height
          padding: const EdgeInsets.all(16.0),
          child: content,
        ),
      ),
    );
  }
}