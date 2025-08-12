// lib/providers/journal_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_exception.dart';
import '../models/journal_timeline_item.dart';
import '../models/loading_indicator_item.dart';
import '../models/journal_entry.dart';
import '../models/ai_comment.dart';
import '../api/api_service.dart';
import '../config.dart';

class JournalProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<JournalTimelineItem> _timelineItems = [];
  bool _isLoading = false;
  String? _error;

  WebSocketChannel? _channel;
  bool _isConnecting = false;

  // Getters
  List<JournalTimelineItem> get timelineItems => _timelineItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void connect() {
    // Prevent multiple connection attempts
    if (_channel != null || _isConnecting) {
      print("WebSocket connection attempt ignored: already connected or connecting.");
      return;
    }

    _isConnecting = true;
    print("WebSocket: Attempting to connect...");

    try {
      // Construct the WebSocket URL. Note the 'ws' scheme instead of 'http'.
      final wsUrl = Uri.parse(AppConfig.baseUrl.replaceFirst('http', 'ws') + '/ws/comments/${AppConfig.testUserId}');
      
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnecting = false;
      print("WebSocket: Connection established.");

      // Start listening for incoming messages immediately
      _channel!.stream.listen(
        (message) {
          // This is the core real-time logic
          _handleIncomingComment(message);
        },
        onDone: () {
          // This is called when the connection is closed by the server or network loss.
          print("WebSocket: Connection closed.");
          _channel = null;
        },
        onError: (error) {
          // Handle any errors from the stream
          print("WebSocket Error: $error");
          _error = "Real-time connection error: $error";
          _channel = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnecting = false;
      _error = "Failed to establish real-time connection.";
      print("WebSocket: Connection failed: $e");
      notifyListeners();
    }
  }

  void disconnect() {
    if (_channel != null) {
      print("WebSocket: Disconnecting...");
      _channel!.sink.close();
      _channel = null;
    }
  }

  // --- Handle Incoming WebSocket Messages ---

  void _handleIncomingComment(String message) {
    print("WebSocket: Received message: $message");
    try {
      final data = jsonDecode(message);
      final newComment = AIComment.fromJsonWithEntryId(data);

      // 1. Check if the loading indicator exists *before* trying to remove it.
      final int loaderIndex = _timelineItems.indexWhere(
          (item) => item is LoadingIndicatorItem && item.entryId == newComment.entryId
      );

      // 2. If it was found (index is not -1), then remove it.
      if (loaderIndex != -1) {
        _timelineItems.removeAt(loaderIndex);
        print("Removed loading indicator for entry ${newComment.entryId}");
      }
      
      // 3. Add the actual new comment to the list
      _timelineItems.add(newComment);

      // 4. Re-sort the entire list to place the new comment correctly
      _timelineItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // 5. Notify the UI to rebuild and show the new comment
      notifyListeners();

    } catch (e) {
      print("Error parsing incoming WebSocket message: $e");
    }
  }

  // This will now be the primary method for fetching and building the journal view.
  Future<void> fetchTimeline() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // The initial fetch logic remains the same
      final results = await Future.wait([
        _apiService.getJournalEntries(),
        _apiService.getAllAIComments(),
      ]);

      final List<JournalEntry> entries = results[0] as List<JournalEntry>;
      final List<AIComment> comments = results[1] as List<AIComment>;

      // 2. Combine them into a single list of the base type
      List<JournalTimelineItem> combinedItems = [];
      combinedItems.addAll(entries);
      combinedItems.addAll(comments);

      // 3. Sort the combined list chronologically
      combinedItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _timelineItems = combinedItems;

    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = "An unexpected error occurred: $e";
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
        
        // Re-sort to place the new entry and its loader correctly at the end
        _timelineItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        notifyListeners();
      } 
    } on ApiException catch (e) {
      _error = "Failed to add entry: $e";
      notifyListeners();
      rethrow;
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
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}