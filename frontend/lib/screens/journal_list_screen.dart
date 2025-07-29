// lib/screens/journal_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/journal_provider.dart';
import '../models/journal_timeline_item.dart';
import '../models/journal_entry.dart';
import '../models/ai_comment.dart';
import 'add_journal_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  _JournalScreenState createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch the timeline when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<JournalProvider>(context, listen: false).fetchTimeline();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          // A refresh button can be useful for debugging
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => Provider.of<JournalProvider>(context, listen: false).fetchTimeline(),
          )
        ],
      ),
      body: Consumer<JournalProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.timelineItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.timelineItems.isEmpty) {
            return const Center(child: Text("Your journal is empty. Add an entry to begin!"));
          }
          // The ListView now builds based on the item's type
          return ListView.builder(
            reverse: true, // For chat-like order
            padding: const EdgeInsets.all(8.0),
            itemCount: provider.timelineItems.length,
            itemBuilder: (context, index) {
              // The 'reverse: true' ListView gives us an index from 0 to (length - 1).
              // We want to map this to our list from the end to the beginning.
              final item = provider.timelineItems[provider.timelineItems.length - 1 - index];
              if (item is JournalEntry) {
                return _UserJournalBubble(entry: item);
              } else if (item is AIComment) {
                return _AiCommentBubble(comment: item);
              }
              return const SizedBox.shrink(); // Should not happen
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool entryAdded = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddJournalScreen()),
          );
          if (entryAdded == true) {
            // The provider's addJournalEntry method now handles refreshing the timeline
          }
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.green, // Your primary color
      ),
    );
  }
}

// --- WIDGET FOR THE USER'S JOURNAL ENTRY BUBBLE ---
class _UserJournalBubble extends StatelessWidget {
  final JournalEntry entry;
  const _UserJournalBubble({Key? key, required this.entry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[100], // A distinct color for the user
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Journal Entry",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
            ),
            Text(DateFormat('MMM d, h:mm a').format(entry.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 5),
            Text(entry.content, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET FOR THE AI'S COMMENT BUBBLE ---
class _AiCommentBubble extends StatelessWidget {
  final AIComment comment;
  const _AiCommentBubble({Key? key, required this.comment}) : super(key: key);

  static const agentData = {
    'financial_advisor': {'icon': Icons.monetization_on, 'name': 'Financial Advisor'},
    'personal_trainer': {'icon': Icons.fitness_center, 'name': 'Personal Trainer'},
    'mental_health_professional': {'icon': Icons.psychology, 'name': 'Mental Health Coach'},
    'career_coach': {'icon': Icons.work, 'name': 'Career Coach'},
    'communication_coach': {'icon': Icons.record_voice_over, 'name': 'Communication Coach'},
    'productivity_coach': {'icon': Icons.timer, 'name': 'Productivity Coach'},
    'personal_stylist': {'icon': Icons.style, 'name': 'Personal Stylist'},
  };

  @override
  Widget build(BuildContext context) {
    final data = agentData[comment.agentName] ?? {'icon': Icons.android, 'name': 'AI Agent'};

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200], // A neutral color for AIs
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topLeft: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['name'] as String,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            Text(DateFormat('MMM d, h:mm a').format(comment.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 5),
            Text(comment.commentText, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}