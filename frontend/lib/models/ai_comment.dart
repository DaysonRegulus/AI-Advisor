// lib/models/ai_comment.dart

class AIComment {
  final String agentName;
  final String commentText;

  AIComment({
    required this.agentName,
    required this.commentText,
  });

  factory AIComment.fromJson(Map<String, dynamic> json) {
    return AIComment(
      agentName: json['agent_name'],
      commentText: json['comment_text'],
    );
  }
}