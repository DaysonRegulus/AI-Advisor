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
        newEntry.areCommentsLoading = true; // Start the "thinking" indicator

        // Add the new entry to the end of our local list.
        _timelineItems.add(newEntry);

        // The JournalScreen will now rebuild and show the new entry with its loading indicator.
        notifyListeners();

        // The UI is already updated and responsive.
        await _pollForComments(newEntry.id);
      } else {
        // Handle the case where the server failed to return the new entry
        _error = "Failed to save journal entry on the server.";
        notifyListeners();
      }
    } catch (e) {
      _error = "Failed to add journal entry: $e";
      notifyListeners();
    }
  }
  // --- NEW HELPER METHOD ---
  void _updateEntryComments(String entryId, List<AIComment> comments) {
    final entryIndex = _timelineItems.indexWhere(
      (item) => item is JournalEntry && item.id == entryId
    );

    if (entryIndex != -1) {
      final entry = _timelineItems[entryIndex] as JournalEntry;
      entry.comments = comments;
      entry.areCommentsLoading = false; // Turn off the indicator
      notifyListeners();
    }
  }

  // --- REVISED: _pollForComments ---
  Future<void> _pollForComments(String entryId) async {
    const int maxRetries = 10;
    const Duration delay = Duration(seconds: 5);

    for (int i = 0; i < maxRetries; i++) {
      await Future.delayed(delay);
      print("Polling for comments... Attempt ${i + 1}");
      
      final comments = await _apiService.getJournalComments(entryId);
      if (comments.isNotEmpty) {
        print("Comments found for entry $entryId!");
        _updateEntryComments(entryId, comments);
        return; // Exit polling successfully
      }
    }

    // If polling times out, we still need to update the UI to stop the loading indicator.
    print("Polling timed out for entry $entryId.");
    _updateEntryComments(entryId, []); // Pass an empty list to stop the indicator
  }
}