// lib/providers/journal_provider.dart

import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../models/ai_comment.dart';
import '../api/api_service.dart';

class JournalProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<JournalEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<JournalEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Core Methods ---

  Future<void> fetchJournalEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedEntries = await _apiService.getJournalEntries();
      // To make the list view act like a chat (newest at the bottom),
      // we reverse the list here. The UI will use reverse: true on the ListView.
      _entries = fetchedEntries.reversed.toList();

      // Immediately fetch comments for all loaded entries ---
      // We don't want to wait for one to finish before starting the next,
      // so we kick them all off concurrently.
      for (final entry in _entries) {
        // We call the method but don't use 'await' here.
        // This lets all comment fetches run in the background simultaneously.
        // The UI will update reactively as each one completes.
        fetchCommentsForEntry(entry.id);
      }
    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addJournalEntry(String content) async {
    try {
      // Add the entry optimistically to the UI first
      final newEntry = await _apiService.addJournalEntry(content);
      if (newEntry != null) {
        _entries.insert(0, newEntry);
        // Set its comment loading state to true immediately
        setCommentLoadingState(newEntry.id, true);
        notifyListeners();
        
        // Now, start polling for comments
        await _pollForComments(newEntry.id);
      }
    } catch (e) {
      // Handle error, maybe remove the optimistic entry
      _error = "Failed to add journal entry: $e";
      notifyListeners();
    }
  }

  Future<void> fetchCommentsForEntry(String entryId, {bool isPoll = false}) async {
    // Find the index of the entry we need to update
    final entryIndex = _entries.indexWhere((e) => e.id == entryId);
    if (entryIndex == -1) return; // Entry not found

    // Set loading state only if we're not silently polling
    if (!isPoll) {
      _entries[entryIndex].areCommentsLoading = true;
      notifyListeners();
    }

    try {
      final comments = await _apiService.getJournalComments(entryId);
      // Permanently attach the fetched comments to the entry object
      _entries[entryIndex].comments = comments;
    } catch (e) {
      print("Error fetching comments: $e");
      // Optionally handle the error in the UI
    }
    
    // Turn off loading state regardless of outcome
    _entries[entryIndex].areCommentsLoading = false;
    notifyListeners();
  }

  Future<void> _pollForComments(String entryId) async {
    const int maxRetries = 10;
    const Duration delay = Duration(seconds: 5);

    for (int i = 0; i < maxRetries; i++) {
      await Future.delayed(delay);
      print("Polling for comments... Attempt ${i + 1}");
      
      final comments = await _apiService.getJournalComments(entryId);
      if (comments.isNotEmpty) {
        print("Comments found!");
        // Call the main fetch function to update the state
        await fetchCommentsForEntry(entryId, isPoll: true);
        return; // Exit polling
      }
    }
    print("Polling timed out. Comments not found.");
    // Ensure loading state is turned off on timeout
    final entryIndex = _entries.indexWhere((e) => e.id == entryId);
    if (entryIndex != -1) {
      _entries[entryIndex].areCommentsLoading = false;
      notifyListeners();
    }
  }


  // --- Helper Methods to update local state ---

  void setCommentLoadingState(String entryId, bool isLoading) {
    final entryIndex = _entries.indexWhere((e) => e.id == entryId);
    if (entryIndex != -1) {
      _entries[entryIndex].areCommentsLoading = isLoading;
      notifyListeners();
    }
  }

  void toggleEntryExpansion(String entryId) {
    final entryIndex = _entries.indexWhere((e) => e.id == entryId);
    if (entryIndex != -1) {
      _entries[entryIndex].isExpanded = !_entries[entryIndex].isExpanded;
      notifyListeners();
    }
  }

  void toggleCommentVisibility(String entryId) {
    final entryIndex = _entries.indexWhere((e) => e.id == entryId);
    if (entryIndex != -1) {
      _entries[entryIndex].areCommentsVisible = !_entries[entryIndex].areCommentsVisible;
      notifyListeners();
    }
  }
}