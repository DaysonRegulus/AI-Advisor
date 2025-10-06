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
import '../core/services/secure_storage_service.dart';
import '../locator.dart';

class JournalProvider with ChangeNotifier {
  // Dependencies from our service locator
  final ApiService _apiService = locator<ApiService>();
  final SecureStorageService _storageService = locator<SecureStorageService>(); // <-- NEW DEPENDENCY

  List<JournalTimelineItem> _timelineItems = [];
  bool _isLoading = false;
  String? _error;

  WebSocketChannel? _channel;
  bool _isConnecting = false;

  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Getters
  List<JournalTimelineItem> get timelineItems => _timelineItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  /// Establishes a secure WebSocket connection using the user's auth token.
  Future<void> connect() async { // <-- Method is now async
    // Prevent multiple connection attempts
    if (_channel != null || _isConnecting) {
      print("WebSocket: Connection attempt ignored: already connected or connecting.");
      return;
    }

    _isConnecting = true;
    print("WebSocket: Attempting to connect...");

    try {
      // 1. GET THE TOKEN: First, retrieve the access token from secure storage.
      final accessToken = await _storageService.getAccessToken();

      // 2. HANDLE EDGE CASE: If no token exists, the user is logged out. Do not connect.
      if (accessToken == null || accessToken.isEmpty) {
        print("WebSocket: No auth token found. Connection aborted.");
        _isConnecting = false;
        return;
      }

      // 3. CONSTRUCT THE SECURE URL: Append the token as a query parameter.
      final wsUrl = Uri.parse(
        AppConfig.baseUrl.replaceFirst('http', 'ws') + '/ws/comments?token=$accessToken'
      );
      
      print('WebSocket: Connecting to $wsUrl'); // For debugging

      _channel = WebSocketChannel.connect(wsUrl);
      _isConnecting = false;
      print("WebSocket: Connection established.");

      // Start listening for incoming messages (this logic is unchanged)
      _channel!.stream.listen(
        (message) {
          _handleIncomingComment(message);
        },
        onDone: () {
          print("WebSocket: Connection closed.");
          _channel = null;
        },
        onError: (error) {
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

  // All other methods below this point are UNCHANGED.
  // disconnect(), _handleIncomingComment(), fetchInitialTimeline(), 
  // fetchNextPage(), addJournalEntry(), and dispose() remain exactly the same.

  void disconnect() {
    if (_channel != null) {
      print("WebSocket: Disconnecting...");
      _channel!.sink.close();
      _channel = null;
    }
  }

  void _handleIncomingComment(String message) {
    print("WebSocket: Received message: $message");
    try {
      final data = jsonDecode(message);
      final newComment = AIComment.fromJsonWithEntryId(data);

      final int loaderIndex = _timelineItems.indexWhere(
          (item) => item is LoadingIndicatorItem && item.entryId == newComment.entryId
      );

      if (loaderIndex != -1) {
        _timelineItems.removeAt(loaderIndex);
        print("Removed loading indicator for entry ${newComment.entryId}");
      }
      
      _timelineItems.add(newComment);
      _timelineItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();

    } catch (e) {
      print("Error parsing incoming WebSocket message: $e");
    }
  }

  Future<void> fetchInitialTimeline() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _currentPage = 0;
    _timelineItems = [];
    _hasMoreData = true;

    await fetchNextPage();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchNextPage() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    
    try {
      final newItems = await _apiService.fetchTimelinePage(_currentPage);

      if (newItems.isEmpty || newItems.length < 20) {
        _hasMoreData = false;
      }

      _timelineItems.addAll(newItems);
      _currentPage++;

    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> addJournalEntry(String content) async {
    try {
      final newEntryFromServer = await _apiService.addJournalEntry(content);
      
      if (newEntryFromServer != null) {
        _timelineItems.insert(0, newEntryFromServer);
        _timelineItems.insert(1, LoadingIndicatorItem(
          entryId: newEntryFromServer.id,
          createdAt: newEntryFromServer.createdAt.add(const Duration(milliseconds: 1)),
        ));
        
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