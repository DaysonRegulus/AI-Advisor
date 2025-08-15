// lib/screens/agent_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

// The ChatMessage model we updated earlier
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTypingIndicator;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isTypingIndicator = false,
    this.isError = false,
  });
}

class AgentChatScreen extends StatefulWidget {
  // It no longer needs agentName, only the title for the AppBar
  final String agentTitle;

  const AgentChatScreen({Key? key, required this.agentTitle}) : super(key: key);

  @override
  _AgentChatScreenState createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add a listener to the scroll controller to detect when the user
    // has scrolled to the top of the list, so we can load older messages.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    // This is the core logic for triggering pagination.
    // If the scroll position is at the very end (top of the reversed list),
    // we trigger the provider to fetch the next page.
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      context.read<ChatProvider>().fetchNextPage();
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    // Use the provider to send the message. This encapsulates all the logic.
    context.read<ChatProvider>().sendMessage(_controller.text.trim());

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.agentTitle)),
      body: Column(
        children: [
          // The main chat view area
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null && provider.messages.isEmpty) {
                  return Center(child: Text("Error: ${provider.error}", style: const TextStyle(color: Colors.red)));
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Crucial for chat UIs
                  padding: const EdgeInsets.all(8.0),
                  // Add +1 to the item count for the loading spinner at the top
                  itemCount: provider.messages.length + (provider.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // If we are at the top and loading more, show a spinner
                    if (provider.isLoadingMore && index == provider.messages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final message = provider.messages[index];
                    return _ChatMessageBubble(message: message);
                  },
                );
              },
            ),
          ),

          // The text input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
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

// --- NEW: A dedicated stateless widget for the chat bubble ---
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Special case for the "typing..." indicator
    if (message.isTypingIndicator) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text("Agent is typing...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      );
    }

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isError
              ? Colors.red[100]
              : message.isUser
                  ? Colors.green[100]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: message.isUser
            ? Text(message.text, style: const TextStyle(fontSize: 16))
            : MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: message.isError ? Colors.red[900] : null,
                  ),
                ),
                selectable: true,
              ),
      ),
    );
  }
}