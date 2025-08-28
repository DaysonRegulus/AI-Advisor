// lib/widgets/food_timeline.dart
import 'package:flutter/material.dart';

class FoodTimeline extends StatelessWidget {
  const FoodTimeline({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This is a placeholder for now. We will build the full,
    // data-driven timeline when we implement the "Add Food" screen.
    // For now, it shows the "onboarding" state.
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            "Your daily food log will appear here.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to the "Add Food" screen
              print("Navigate to Add Food Screen");
            },
            icon: const Icon(Icons.add),
            label: const Text("Log Your First Meal"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }
}