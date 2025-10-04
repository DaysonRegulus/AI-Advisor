// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/daily_summary_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/goal_provider.dart';

import '../widgets/daily_summary_card.dart';
import '../widgets/xp_progress_bar.dart';
import '../widgets/water_tracker_card.dart';
import '../widgets/weight_tracker_card.dart';
import '../widgets/calorie_tracker_header.dart'; 
import '../widgets/food_timeline.dart';
import '../features/authentication/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  // Add a final variable to hold the function
  final Future<void> Function() onRefresh;

  // Update the constructor to require this function
  const HomeScreen({Key? key, required this.onRefresh}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We fetch the dashboard data here when the screen is built.
    // This is better than the main_scaffold for screen-specific data.
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    if (dashboardProvider.latestWeightLog == null) { // Simple check to see if we've fetched data
      dashboardProvider.fetchDashboardData();
    }
    
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    if (goalProvider.userGoals == null) {
      goalProvider.fetchGoals();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Button to trigger the summary generation
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Generate/Refresh Daily Summary',
            onPressed: () {
              Provider.of<DailySummaryProvider>(context, listen: false).fetchLatestSummary();
            },
          ),
          // Test button to award XP
          IconButton(
            icon: const Icon(Icons.add_circle),
            tooltip: 'Award 15 XP',
            onPressed: () {
              Provider.of<UserProfileProvider>(context, listen: false).awardXpForEvent('manual_test_button', 15);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Call the logout method from our AuthProvider
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: const [
              Row(
                children: const [
                  Expanded(child: XpProgressBar()), // Takes up left side
                  Expanded(child: CalorieTrackerHeader()), // Takes up right side
                  // We can add other quick stats here later
                ],
              ),
              const SizedBox(height: 16),
              const Text("Today's Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const DailySummaryCard(),
              const SizedBox(height: 16),
              const Divider(indent: 16, endIndent: 16),

              const SizedBox(height: 16),
            
              // --- TRACKER CARDS ---
              const WaterTrackerCard(),
              const SizedBox(height: 8),
              const WeightTrackerCard(),

              const SizedBox(height: 24),

              // --- FOOD TIMELINE ---
              const Text(
                "Today's Food Log",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 16),
              const FoodTimeline(),
            ],
          ),
        ),
      ),
    );
  }
}