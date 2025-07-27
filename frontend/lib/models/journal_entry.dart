// lib/models/journal_entry.dart

import 'ai_comment.dart';

class JournalEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  
  // New properties for the interactive UI
  List<AIComment> comments;
  bool areCommentsLoading;
  bool isExpanded;

  JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.comments = const [],
    this.areCommentsLoading = false,
    this.isExpanded = false,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}