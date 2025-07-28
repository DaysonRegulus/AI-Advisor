// lib/models/journal_chat_item.dart

import 'journal_entry.dart';
import 'ai_comment.dart';

// This is the "base" class. It's abstract, meaning you can't create an instance of it directly.
@immutable // A good practice for model classes to make them immutable.
abstract class JournalChatItem {
  final DateTime timestamp;
  const JournalChatItem({required this.timestamp});
}

// A class representing the user's journal entry as a chat bubble.
class UserJournalItem extends JournalChatItem {
  final JournalEntry entry;
  const UserJournalItem({required this.entry}) : super(timestamp: entry.createdAt);
}

// A class representing an AI's comment as a chat bubble.
class AgentCommentItem extends JournalChatItem {
  final AIComment comment;
  // We need the timestamp for sorting, but the comment model doesn't have it.
  // We will need to add it. For now, we'll use a placeholder.
  const AgentCommentItem({required this.comment, required DateTime createdAt}) : super(timestamp: createdAt);
}

// A class representing the "Agents are thinking..." indicator.
class LoadingIndicatorItem extends JournalChatItem {
   // This item doesn't have a real timestamp, so we use the related entry's time.
  const LoadingIndicatorItem({required DateTime associatedTimestamp}) : super(timestamp: associatedTimestamp);
}