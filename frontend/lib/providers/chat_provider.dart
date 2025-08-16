// lib/providers/chat_provider.dart
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../api/api_exception.dart';
import '../screens/agent_chat_screen.dart'; // We'll need the ChatMessage model from here

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final String agentName;

  ChatProvider({required this.agentName}) {
    // When a provider for a specific agent is created,
    // immediately fetch the first page of their history.
    fetchInitialHistory();
  }

  List<ChatMessage> _messages = [];
  bool _isLoading = true; // For the initial page load
  bool _isLoadingMore = false; // For subsequent pages
  bool _hasMoreData = true;
  int _currentPage = 0;
  String? _error;

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  Future<void> fetchInitialHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _messages = [];
    _currentPage = 0;
    _hasMoreData = true;

    await fetchNextPage();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchNextPage() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    _isLoadingMore = true;
    notifyListeners();

    try {
      // Call the new API method
      final timelineItems = await _apiService.fetchAgentTimelinePage(agentName, _currentPage);

      if (timelineItems.isEmpty) {
        _hasMoreData = false;
      } else {
        // Now we process the unified timeline
        for (var item in timelineItems) {
          if (item.itemType == 'chat_interaction') {
            // This is a standard chat message
            if(item.aiResponse != null) _messages.add(ChatMessage(text: item.aiResponse!, isUser: false));
            if(item.userMessage != null) _messages.add(ChatMessage(text: item.userMessage!, isUser: true));
          } else if (item.itemType == 'journal_comment') {
            // This is a journal comment, which we'll represent as a special AI message
            if(item.aiResponse != null) {
               _messages.add(ChatMessage(
                text: item.aiResponse!,
                isUser: false,
                isJournalComment: true, // <-- The special flag
                entryId: item.entryId,
                journalContent: item.journalContent,
              ));
            }
          }
        }
        _currentPage++;
      }
    } on ApiException catch(e) {
      _error = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    // 1. Optimistically add the user's message to the UI
    final userMessage = ChatMessage(text: text, isUser: true);
    _messages.insert(0, userMessage);
    
    // 2. Add a temporary "typing" indicator
    final typingIndicator = ChatMessage(text: "...", isUser: false, isTypingIndicator: true);
    _messages.insert(0, typingIndicator);
    notifyListeners();

    try {
      // 3. Call the API
      final aiResponseText = await _apiService.interactWithAi(agentName, text);
      final aiMessage = ChatMessage(text: aiResponseText, isUser: false);
      
      // 4. Replace the typing indicator with the real response
      _messages[0] = aiMessage;

    } on ApiException catch (e) {
      final errorMessage = ChatMessage(text: e.message, isUser: false, isError: true);
      _messages[0] = errorMessage;
    } finally {
      notifyListeners();
    }
  }
}