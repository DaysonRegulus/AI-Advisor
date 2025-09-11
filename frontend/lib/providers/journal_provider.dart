// lib/providers/journal_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_exception.dart';
import '../models/journal_timeline_item.dart';
import '../models/loading_indicator_item.dart';
import '../models/ai_comment.dart';
import '../api/api_service.dart';
import '../config.dart';
import '../locator.dart';

class JournalProvider with ChangeNotifier {
  // Get the ApiService instance from the locator.
  final ApiService _apiService = locator<ApiService>();
  List<JournalTimelineItem> _timelineItems = [];
  bool _isLoading = false;
  String? _error;

  WebSocketChannel? _channel;
  bool _isConnecting = false;

  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false; // For loading subsequent pages

  // Getters
  List<JournalTimelineItem> get timelineItems => _timelineItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
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
  Future<void> fetchInitialTimeline() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Reset state for a fresh fetch
    _currentPage = 0;
    _timelineItems = [];
    _hasMoreData = true;

    await fetchNextPage(); // Call the main pagination logic

    _isLoading = false;
    notifyListeners();
  }

  // --- NEW: The core pagination logic ---
  Future<void> fetchNextPage() async {
    // Prevent multiple simultaneous requests
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    // Don't call notifyListeners here for a silent background load
    
    try {
      final newItems = await _apiService.fetchTimelinePage(_currentPage);

      if (newItems.isEmpty || newItems.length < 20) {
        // If we receive fewer items than the page size, we've reached the end.
        _hasMoreData = false;
      }

      _timelineItems.addAll(newItems);
      _currentPage++;

    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners(); // Notify UI of all changes (new items, error, etc.)
    }
  }

  // The "add" method now just adds the entry and then re-fetches the whole timeline
  // to ensure perfect chronological consistency.
  Future<void> addJournalEntry(String content) async {
    try {
      final newEntryFromServer = await _apiService.addJournalEntry(content);
      
      if (newEntryFromServer != null) {
        // OPTIMISTICALLY UPDATE THE UI STATE
        
        // Instead of re-fetching, we now optimistically update the state.
        // Since our list is newest-first from the API, we insert at the start.
        _timelineItems.insert(0, newEntryFromServer);
        _timelineItems.insert(1, LoadingIndicatorItem(
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

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}