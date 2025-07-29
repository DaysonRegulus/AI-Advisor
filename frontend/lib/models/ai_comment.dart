// lib/models/ai_comment.dart

import 'journal_timeline_item.dart';

class AIComment extends JournalTimelineItem {
  final String agentName;
  final String commentText;

  AIComment({
    required this.agentName,
    required this.commentText,
    required DateTime createdAt,
  }) : super(createdAt);

  factory AIComment.fromJson(Map<String, dynamic> json) {
    return AIComment(
      agentName: json['agent_name'],
      commentText: json['comment_text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}