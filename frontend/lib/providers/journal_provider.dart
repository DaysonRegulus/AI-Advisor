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
      _entries = await _apiService.getJournalEntries();
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

  Future<void> fetchCommentsForEntry(String entryId) async {
    setCommentLoadingState(entryId, true);
    try {
      final comments = await _apiService.getJournalComments(entryId);
      final entryIndex = _entries.indexWhere((e) => e.id == entryId);
      if (entryIndex != -1) {
        _entries[entryIndex].comments = comments;
      }
    } catch (e) {
      print("Error fetching comments: $e");
    }
    setCommentLoadingState(entryId, false);
  }

  // Polls the backend for comments until they are found or a timeout is reached.
  Future<void> _pollForComments(String entryId) async {
    const int maxRetries = 10;
    const Duration delay = Duration(seconds: 5);

    for (int i = 0; i < maxRetries; i++) {
      await Future.delayed(delay);
      print("Polling for comments... Attempt ${i + 1}");
      final comments = await _apiService.getJournalComments(entryId);
      if (comments.isNotEmpty) {
        print("Comments found!");
        final entryIndex = _entries.indexWhere((e) => e.id == entryId);
        if (entryIndex != -1) {
          _entries[entryIndex].comments = comments;
          setCommentLoadingState(entryId, false); // Turn off loading indicator
        }
        return; // Exit polling
      }
    }
    print("Polling timed out. Comments not found.");
    setCommentLoadingState(entryId, false); // Turn off loading indicator on timeout
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
}