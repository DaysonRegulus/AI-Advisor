// lib/screens/journal_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

import '../providers/journal_provider.dart';
import '../models/journal_entry.dart';
import '../models/ai_comment.dart';
import 'add_journal_screen.dart';

class JournalScreen extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const JournalScreen({Key? key, required this.onRefresh}) : super(key: key);

  @override
  _JournalScreenState createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial entries when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<JournalProvider>(context, listen: false).fetchJournalEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Journal')),
      body: Consumer<JournalProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.entries.isEmpty) {
            return const Center(child: Text("No journal entries yet. Add one!"));
          }
          return ListView.builder(
            itemCount: provider.entries.length,
            itemBuilder: (context, index) {
              final entry = provider.entries[index];
              return JournalEntryCard(entry: entry);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // The new "add" screen will now return true if an entry was added
          final bool entryAdded = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddJournalScreen()),
          );
          // If an entry was added, the provider would have already handled it.
          // This is just a placeholder for potential future logic.
          if (entryAdded == true) {
            // Potentially scroll to top or show a confirmation
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- A new Widget for displaying a single Journal Entry Card ---
class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  const JournalEntryCard({Key? key, required this.entry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM d, yyyy - h:mm a').format(entry.createdAt.toLocal()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => journalProvider.toggleEntryExpansion(entry.id),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: entry.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: Text(entry.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                secondChild: Text(entry.content),
              ),
            ),
            const Divider(height: 24),
            _buildCommentSection(context, entry),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection(BuildContext context, JournalEntry entry) {
    if (entry.areCommentsLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          AnimatedTextKit(
            animatedTexts: [
              WavyAnimatedText('Agents are thinking...'),
            ],
            isRepeatingAnimation: true,
          ),
        ],
      );
    }

    if (entry.comments.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () => Provider.of<JournalProvider>(context, listen: false).fetchCommentsForEntry(entry.id),
          child: const Text("Check for AI Insights"),
        ),
      );
    }

    return Column(
      children: entry.comments.map((comment) => AICommentBubble(comment: comment)).toList(),
    );
  }
}

// --- A new Widget for displaying a single AI Comment Bubble ---
class AICommentBubble extends StatelessWidget {
  final AIComment comment;
  const AICommentBubble({Key? key, required this.comment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // A map to get agent icons easily
    const agentIcons = {
      'financial_advisor': Icons.monetization_on,
      'personal_trainer': Icons.fitness_center,
      'mental_health_professional': Icons.psychology,
      'career_coach': Icons.work,
      'communication_coach': Icons.record_voice_over,
      'productivity_coach': Icons.timer,
      'personal_stylist': Icons.style,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(agentIcons[comment.agentName] ?? Icons.android, size: 18), radius: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(comment.commentText),
            ),
          ),
        ],
      ),
    );
  }
}