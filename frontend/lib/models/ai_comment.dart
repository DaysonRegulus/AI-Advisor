// lib/models/ai_comment.dart

import 'journal_timeline_item.dart';

class AIComment extends JournalTimelineItem {
  final String agentName;
  final String commentText;
  final String entryId;

  AIComment({
    required this.entryId,
    required this.agentName,
    required this.commentText,
    required DateTime createdAt,
  }) : super(createdAt);

  factory AIComment.fromJson(Map<String, dynamic> json) {
    return AIComment(
      entryId: json['entry_id'] ?? '',
      agentName: json['agent_name'],
      commentText: json['comment_text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  factory AIComment.fromJsonWithEntryId(Map<String, dynamic> json) {
    return AIComment(
      entryId: json['entry_id'],
      agentName: json['agent_name'],
      commentText: json['comment_text'],
      // When a comment arrives via WebSocket, it doesn't have a 'created_at' yet.
      // We assign the current time. This is acceptable as it's for display sorting.
      // The true 'created_at' is in the database.
      createdAt: DateTime.now(), 
    );
  }
}