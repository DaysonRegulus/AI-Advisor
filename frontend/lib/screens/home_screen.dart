// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/daily_summary_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/daily_summary_card.dart'; // <-- Import new card
import '../widgets/xp_progress_bar.dart';
import 'agent_chat_screen.dart';
import 'journal_list_screen.dart';

class HomeScreen extends StatelessWidget {
  // Add a final variable to hold the function
  final Future<void> Function() onRefresh;

  // Update the constructor to require this function
  const HomeScreen({Key? key, required this.onRefresh}) : super(key: key);

  // Helper to create a button for an agent
  Widget _agentButton(BuildContext context, String agentName, String agentTitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 40),
      title: Text(agentTitle),
      subtitle: Text('Consult the $agentTitle'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgentChatScreen(agentName: agentName, agentTitle: agentTitle),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Advisor Dashboard'),
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: const [
              Row(
                children: [
                  const XpProgressBar(), // Our new circular progress bar
                  // We can add other quick stats here later
                ],
              ),
              const SizedBox(height: 16),
              const Text("Today's Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const DailySummaryCard(),
              const SizedBox(height: 16),
              const Divider(indent: 16, endIndent: 16),
            ],
          ),
        ),
      ),
    );
  }
}