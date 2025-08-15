// lib/screens/agent_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../api/api_service.dart';

// A simple model for a chat message
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AgentChatScreen extends StatefulWidget {
  final String agentName;
  final String agentTitle;

  const AgentChatScreen({Key? key, required this.agentName, required this.agentTitle}) : super(key: key);

  @override
  _AgentChatScreenState createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = ChatMessage(text: _controller.text, isUser: true);
    setState(() {
      _messages.insert(0, userMessage); // Add message to the top of the list
      _isTyping = true;
    });

    final textToSend = _controller.text;
    _controller.clear();

    final aiResponseText = await _apiService.interactWithAi(widget.agentName, textToSend);
    final aiMessage = ChatMessage(text: aiResponseText, isUser: false);

    setState(() {
      _messages.insert(0, aiMessage);
      _isTyping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.agentTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Makes the list start from the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Align(
                    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: message.isUser
                        ? Text(message.text, style: const TextStyle(fontSize: 16))
                        : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
                          ),
                          selectable: true,
                        ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Agent is typing...")),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}