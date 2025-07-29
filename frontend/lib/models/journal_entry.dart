// lib/models/journal_entry.dart

import 'journal_timeline_item.dart';
import 'ai_comment.dart';

class JournalEntry extends JournalTimelineItem {
  final String id;
  final String content;
  
  // New properties for the interactive UI
  List<AIComment> comments;
  bool areCommentsLoading;
  bool areCommentsVisible;
  bool isExpanded;

  JournalEntry({
    required this.id,
    required this.content,
    required DateTime createdAt,
    this.comments = const [],
    this.areCommentsLoading = false,
    this.areCommentsVisible = true,
    this.isExpanded = false,
  }) : super(createdAt);

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      areCommentsVisible: true,
    );
  }
}