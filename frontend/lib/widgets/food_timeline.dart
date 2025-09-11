// lib/widgets/food_timeline.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // Import for groupBy

import '../providers/food_timeline_provider.dart';
import '../models/food_log.dart';
import '../screens/trackers/add_food_screen.dart';

class FoodTimeline extends StatefulWidget {
  const FoodTimeline({Key? key}) : super(key: key);

  @override
  _FoodTimelineState createState() => _FoodTimelineState();
}

class _FoodTimelineState extends State<FoodTimeline> {
  @override
  void initState() {
    super.initState();
    // Trigger initial fetch when the widget is first created.
    // Use addPostFrameCallback to ensure the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FoodTimelineProvider>(context, listen: false).fetchTodaysFoodLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FoodTimelineProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.foodLogs.isEmpty) {
          return _buildEmptyState(context);
        }

        // Group logs by meal type using the collection package
        final groupedLogs = groupBy(provider.foodLogs, (FoodLog log) => log.mealType);
        
        // Define the order in which meal groups should appear
        final mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Water'];
        final List<Widget> timelineWidgets = [];

        for (var meal in mealOrder) {
          if (groupedLogs.containsKey(meal)) {
            // Add a header for the meal group
            timelineWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(meal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
              )
            );
            // Add a ListTile for each log in that group
            timelineWidgets.addAll(
              groupedLogs[meal]!.map((log) => Card(
                elevation: 1,
                child: ListTile(
                  leading: Icon(
                    log.mealType == 'Water' ? Icons.water_drop_outlined : Icons.restaurant_outlined,
                    color: log.mealType == 'Water' ? Colors.blue : Colors.orange,
                  ),
                  title: Text(log.foodName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Text("${log.calories.toInt()} kcal"),
                  onTap: () {
                    // In the future, this could open a details view for the food item
                  },
                ),
              ))
            );
          }
        }

        // Add the "Log Meal" button at the very end
        timelineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToAddFood(context),
                icon: const Icon(Icons.add),
                label: const Text("Log a Meal or Drink"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          )
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: timelineWidgets
        );
      },
    );
  }

  // Helper function for navigating to the Add Food screen
  void _navigateToAddFood(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFoodScreen()),
    );
  }

  // The onboarding widget for when the timeline is empty
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.menu_book, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Your daily log is empty.",
              style: TextStyle(color: Colors.grey, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddFood(context),
              icon: const Icon(Icons.add),
              label: const Text("Log Your First Meal"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}