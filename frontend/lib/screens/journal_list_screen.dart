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
            reverse: true, // Newest entries at the bottom
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Journal Entry Content (with Read More) ---
            InkWell(
              onTap: () => journalProvider.toggleEntryExpansion(entry.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM d, yyyy - h:mm a').format(entry.createdAt.toLocal()),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  // The 'Read More' functionality is implicitly handled by AnimatedCrossFade
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: entry.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: Text(entry.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                    secondChild: Text(entry.content),
                  ),
                ],
              ),
            ),
            
            // --- Divider and Comments Section ---
            if (entry.comments.isNotEmpty || entry.areCommentsLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: const Divider(height: 16),
              ),
            _buildCommentSection(context, entry),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection(BuildContext context, JournalEntry entry) {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    // --- 1. Loading State ---
    if (entry.areCommentsLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            // --- FIXED ANIMATION ---
            Row(
              children: [
                const Text("Agents are thinking"),
                AnimatedTextKit(
                  animatedTexts: [
                    TyperAnimatedText('...'),
                  ],
                  isRepeatingAnimation: true,
                ),
              ],
            )
          ],
        ),
      );
    }

    // --- 2. No Comments State ---
    // This state should now rarely be seen, as comments are loaded automatically.
    // It acts as a fallback.
    if (entry.comments.isEmpty) {
      return const SizedBox.shrink(); // Render nothing if no comments and not loading
    }

    // --- 3. Comments are available ---
    return Column(
      children: [
        // --- Collapse/Expand Button ---
        InkWell(
          onTap: () => journalProvider.toggleCommentVisibility(entry.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  entry.areCommentsVisible ? "Collapse" : "Show ${entry.comments.length} Comments",
                  style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                ),
                Icon(
                  entry.areCommentsVisible ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ),
        
        // --- The Animated Comment List ---
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SizeTransition(sizeFactor: animation, child: child);
          },
          child: entry.areCommentsVisible
              ? Column(
                  // Use a unique key to help the animation
                  key: ValueKey<int>(entry.comments.length),
                  children: entry.comments.map((comment) => AICommentBubble(comment: comment)).toList(),
                )
              // Render an empty container when comments are not visible
              : const SizedBox.shrink(key: ValueKey<int>(0)),
        ),
      ],
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