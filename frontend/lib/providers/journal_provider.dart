// lib/providers/journal_provider.dart

import 'package:flutter/material.dart';
import '../models/journal_timeline_item.dart';
import '../models/loading_indicator_item.dart';
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
      final newEntryFromServer = await _apiService.addJournalEntry(content);
      
      if (newEntryFromServer != null) {
        // OPTIMISTICALLY UPDATE THE UI STATE
        
        // 1. Add the new journal entry itself.
        _timelineItems.add(newEntryFromServer);
        
        // 2. Add our new loading indicator right after it.
        _timelineItems.add(LoadingIndicatorItem(
          entryId: newEntryFromServer.id,
          // We give it a slightly later timestamp to ensure it sorts correctly.
          createdAt: newEntryFromServer.createdAt.add(const Duration(milliseconds: 1)),
        ));
        
        // 3. Notify the UI immediately.
        notifyListeners();
        
        // 4. Start the polling process in the background.
        await _pollForComments(newEntryFromServer.id);
      } else {
        _error = "Failed to save journal entry on the server.";
        notifyListeners();
      }
    } catch (e) {
      _error = "An error occurred while adding the journal entry: $e";
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
      print("Polling for comments... Attempt ${i + 1} for entry $entryId");
      
      final comments = await _apiService.getJournalComments(entryId);
      if (comments.isNotEmpty) {
        print("Comments found for entry $entryId!");
        
        // --- NEW LOGIC ---
        // 1. Remove the temporary loading indicator.
        _timelineItems.removeWhere((item) => item is LoadingIndicatorItem && item.entryId == entryId);

        // 2. Add the actual comments to the list.
        _timelineItems.addAll(comments);

        // 3. Re-sort the entire list to place comments correctly.
        _timelineItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // 4. Notify the UI of the final state.
        notifyListeners();
        return; // Exit polling
      }
    }

    // If polling times out, just remove the loading indicator.
    print("Polling timed out for entry $entryId.");
    _timelineItems.removeWhere((item) => item is LoadingIndicatorItem && item.entryId == entryId);
    notifyListeners();
  }
}