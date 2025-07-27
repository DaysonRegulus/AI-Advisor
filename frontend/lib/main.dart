// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/daily_summary_provider.dart';
import 'providers/journal_provider.dart';
import 'screens/home_screen.dart';
import 'screens/main_scaffold.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We use MultiProvider to provide multiple objects to the widget tree.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProfileProvider()),
        ChangeNotifierProvider(create: (context) => DailySummaryProvider()),
        ChangeNotifierProvider(create: (context) => JournalProvider()), // <-- Add new provider
      ],
      child: MaterialApp(
        title: 'Personal AI Advisor',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainScaffold(),
      ),
    );
  }
}