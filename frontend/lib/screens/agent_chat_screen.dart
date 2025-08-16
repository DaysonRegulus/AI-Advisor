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
  final bool isJournalComment;
  final String? entryId;
  final String? journalContent;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isTypingIndicator = false,
    this.isError = false,
    this.isJournalComment = false, 
    this.entryId,
    this.journalContent,
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
    // Special case for the "typing..." indicator (this logic is unchanged)
    if (message.isTypingIndicator) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text("Agent is typing...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      );
    }

    // Determine bubble alignment and color based on message type
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isError
        ? Colors.red[100]
        : message.isUser
            ? Colors.green[100]
            : Colors.grey[200];
    final textColor = message.isError ? Colors.red[900] : null;

    // --- Conditionally build the content of the bubble ---
    Widget bubbleContent;

    if (message.isJournalComment) {
      // This is a special comment bubble with a "quoted reply"
      bubbleContent = _buildJournalCommentContent(context, textColor);
    } else {
      // This is a standard chat message
      bubbleContent = _buildStandardMessageContent(context, textColor);
    }

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: bubbleContent,
      ),
    );
  }

  // --- Helper method to build a standard message ---
  Widget _buildStandardMessageContent(BuildContext context, Color? textColor) {
    return message.isUser
        ? Text(message.text, style: TextStyle(fontSize: 16, color: textColor))
        : MarkdownBody(
            data: message.text,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    color: textColor,
                  ),
            ),
          );
  }

  // --- Helper method to build the rich journal comment content ---
  Widget _buildJournalCommentContent(BuildContext context, Color? textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "Quoted Reply" Snippet
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05), // A slightly darker shade
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: Colors.green.shade300, // Accent color
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Regarding your journal entry:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.journalContent ?? "Could not load journal content.",
                maxLines: 2, // Show a snippet
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // The actual AI comment, rendered with Markdown
        MarkdownBody(
          data: message.text,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: textColor,
                ),
          ),
        ),
      ],
    );
  }
}