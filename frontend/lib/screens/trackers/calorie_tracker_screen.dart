// lib/screens/trackers/calorie_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calorie_provider.dart';
import '../../providers/goal_provider.dart';
import '../../models/nutrient_breakdown.dart';

class CalorieTrackerScreen extends StatefulWidget {
  const CalorieTrackerScreen({Key? key}) : super(key: key);

  @override
  _CalorieTrackerScreenState createState() => _CalorieTrackerScreenState();
}

class _CalorieTrackerScreenState extends State<CalorieTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch data when the screen loads
      Provider.of<CalorieProvider>(context, listen: false).fetchBreakdown();
    });
  }

  @override
  Widget build(BuildContext context) {
    final calorieProvider = Provider.of<CalorieProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);
    
    final breakdown = calorieProvider.breakdown;
    final calorieGoal = goalProvider.userGoals?.dailyCalorieGoal ?? 2000;

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Nutrition")),
      body: calorieProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : breakdown == null
              ? const Center(child: Text("No data for today."))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMacroSection(breakdown, calorieGoal),
                    const Divider(height: 32),
                    _buildMicroSection(breakdown),
                  ],
                ),
    );
  }

  Widget _buildMacroSection(NutrientBreakdown breakdown, int goal) {
    final protein = breakdown.macros['protein'] ?? 0;
    final carbs = breakdown.macros['carbs'] ?? 0;
    final fat = breakdown.macros['fat'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Macros", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _NutrientProgressIndicator(
          name: "Calories",
          value: breakdown.totalCalories,
          goal: goal.toDouble(),
          unit: "kcal",
          color: Colors.orange,
        ),
        _NutrientProgressIndicator(name: "Protein", value: protein, goal: 120, unit: "g", color: Colors.red),
        _NutrientProgressIndicator(name: "Carbs", value: carbs, goal: 250, unit: "g", color: Colors.blue),
        _NutrientProgressIndicator(name: "Fat", value: fat, goal: 70, unit: "g", color: Colors.amber),
      ],
    );
  }

  Widget _buildMicroSection(NutrientBreakdown breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Micronutrients", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        // Create a list of tiles for each micro
        ...breakdown.micros.entries.map((entry) => ListTile(
              title: Text(entry.key.replaceAll('_', ' ').capitalize()),
              trailing: Text("${entry.value.toStringAsFixed(1)} g/mg"),
            )).toList(),
      ],
    );
  }
}

// Helper widget for progress bars
class _NutrientProgressIndicator extends StatelessWidget {
  final String name; final double value; final double goal; final String unit; final Color color;
  const _NutrientProgressIndicator({required this.name, required this.value, required this.goal, required this.unit, required this.color});
  
  @override
  Widget build(BuildContext context) {
    final percent = goal > 0 ? (value / goal) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit"),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: percent, color: color, backgroundColor: color.withOpacity(0.2)),
        ],
      ),
    );
  }
}

// String extension to capitalize words
extension StringExtension on String {
  String capitalize() {
      return "${this[0].toUpperCase()}${substring(1)}";
  }
}
