// lib/providers/journal_provider.dart

import 'package:flutter/material.dart';
import '../models/journal_timeline_item.dart';
import '../models/journal_entry.dart';
import '../models/ai_comment.dart';
import '../api/api_service.dart';

class JournalProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<JournalTimelineItem> _timelineItems = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<JournalTimelineItem> get timelineItems => _timelineItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // This will now be the primary method for fetching and building the journal view.
  Future<void> fetchTimeline() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch both data sources concurrently
      final futureEntries = _apiService.getJournalEntries();
      final futureComments = _apiService.getAllAIComments();

      // Wait for both network calls to complete
      final results = await Future.wait([futureEntries, futureComments]);

      final List<JournalEntry> entries = results[0] as List<JournalEntry>;
      final List<AIComment> comments = results[1] as List<AIComment>;

      // 2. Combine them into a single list of the base type
      List<JournalTimelineItem> combinedItems = [];
      combinedItems.addAll(entries);
      combinedItems.addAll(comments);

      // 3. Sort the combined list chronologically
      combinedItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _timelineItems = combinedItems;

    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // The "add" method now just adds the entry and then re-fetches the whole timeline
  // to ensure perfect chronological consistency.
  Future<void> addJournalEntry(String content) async {
    try {
      final newEntry = await _apiService.addJournalEntry(content);
      if (newEntry != null) {
        // After successfully adding, refresh the entire timeline
        // to get the new entry and its eventual comments.
        await fetchTimeline();
      }
    } catch (e) {
      _error = "Failed to add journal entry: $e";
      notifyListeners();
    }
  }
}