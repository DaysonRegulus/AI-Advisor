// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/daily_summary_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/food_timeline_provider.dart';
import 'providers/refresh_provider.dart';
import 'providers/calorie_provider.dart';
import 'features/authentication/screens/auth_wrapper.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'locator.dart';

void main() {
  setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We use MultiProvider to provide multiple objects to the widget tree.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => UserProfileProvider()),
        ChangeNotifierProvider(create: (context) => DailySummaryProvider()),
        ChangeNotifierProvider(create: (context) => JournalProvider()),
        ChangeNotifierProvider(create: (context) => GoalProvider()),
        ChangeNotifierProvider(create: (context) => DashboardProvider()),
        ChangeNotifierProvider(create: (context) => FoodTimelineProvider()),
        ChangeNotifierProvider(create: (context) => RefreshProvider()),
        ChangeNotifierProvider(create: (context) => CalorieProvider()),
      ],
      child: MaterialApp(
        title: 'Personal AI Advisor',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}