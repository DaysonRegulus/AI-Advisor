// lib/models/journal_timeline_item.dart

// An abstract class that defines the one thing all items on our timeline must have: a creation date for sorting.
abstract class JournalTimelineItem {
  final DateTime createdAt;
  JournalTimelineItem(this.createdAt);
}