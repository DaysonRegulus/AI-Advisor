// lib/screens/journal_list_screen.dart
import 'dart:ui' as ui;

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/journal_provider.dart';
import '../models/journal_timeline_item.dart';
import '../models/loading_indicator_item.dart';
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
          if (provider.error != null && provider.timelineItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Could not load journal:\n${provider.error}",
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
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
              } else if (item is LoadingIndicatorItem) {
                return const _AiThinkingBubble();
              }
              return const SizedBox.shrink(); // Should not happen
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // We now 'await' the result of the push navigation.
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddJournalScreen()),
          );
          // If the result is true, it means the save process was successfully started.
          if (result == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Journal entry saved! Agents are reviewing it...'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.green, // primary color
      ),
    );
  }
}

// --- WIDGET FOR THE USER'S JOURNAL ENTRY BUBBLE ---
class _UserJournalBubble extends StatefulWidget {
  final JournalEntry entry;
  const _UserJournalBubble({Key? key, required this.entry}) : super(key: key);

  @override
  __UserJournalBubbleState createState() => __UserJournalBubbleState();
}

class __UserJournalBubbleState extends State<_UserJournalBubble> {
  bool _isExpanded = false;
  bool _isExpandable = false;

  @override
  Widget build(BuildContext context) {
    // We use a LayoutBuilder to determine if the text will overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Create a TextPainter to measure the text.
        final textPainter = TextPainter(
          text: TextSpan(text: widget.entry.content, style: const TextStyle(fontSize: 16)),
          maxLines: 3, // The number of lines before it's considered "overflowing"
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth); // Layout with the available width

        // Check if the text actually exceeds the max lines.
        // We only want to show "Read More" if it's necessary.
        if (textPainter.didExceedMaxLines && !_isExpandable) {
          // If it overflows, we update the state to mark it as expandable.
          // We use addPostFrameCallback to avoid causing errors during a build phase.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted) {
              setState(() {
                _isExpandable = true;
              });
            }
          });
        }
        
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
            child: InkWell(
              onTap: _isExpandable ? () => setState(() => _isExpanded = !_isExpanded) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "My Journal Entry",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
                  ),
                  Text(DateFormat('MMM d, h:mm a').format(widget.entry.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(height: 5),
                  Text(
                    widget.entry.content,
                    style: const TextStyle(fontSize: 16),
                    maxLines: _isExpanded ? null : 3, // Show all lines if expanded
                    overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  // --- THE FIX: Conditionally show the "Read More" text ---
                  if (_isExpandable && !_isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Read more...",
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGET FOR THE AI'S COMMENT BUBBLE ---
class _AiCommentBubble extends StatelessWidget {
  final AIComment comment;
  const _AiCommentBubble({Key? key, required this.comment}) : super(key: key);

  // The agent data map remains the same, it's correct.
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Row( // <-- The Row layout is key
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- THE MISSING ICON WIDGET ---
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[300],
            child: Icon(
              data['icon'] as IconData,
              size: 18,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),

          // The comment bubble container
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
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
          ),
        ],
      ),
    );
  }
}

// --- WIDGET FOR THE "AGENTS ARE THINKING" BUBBLE ---
class _AiThinkingBubble extends StatelessWidget {
  const _AiThinkingBubble({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200], // A neutral color
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topLeft: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // The Row should only be as wide as its content
          children: [
            const Text(
              "Agents are thinking",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            // This AnimatedTextKit now only controls the ellipsis
            AnimatedTextKit(
              animatedTexts: [
                TyperAnimatedText(
                  '...',
                  textStyle: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  speed: const Duration(milliseconds: 200),
                ),
              ],
              isRepeatingAnimation: true,
              repeatForever: true,
            ),
          ],
        ),
      ),
    );
  }
}