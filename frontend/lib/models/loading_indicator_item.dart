// lib/models/loading_indicator_item.dart
import 'journal_timeline_item.dart';

class LoadingIndicatorItem extends JournalTimelineItem {
  // This ID links the indicator to the journal entry it's waiting on.
  final String entryId;

  LoadingIndicatorItem({required this.entryId, required DateTime createdAt}) : super(createdAt);
}