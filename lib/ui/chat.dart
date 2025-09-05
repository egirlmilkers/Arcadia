import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';

class ChatUI extends StatefulWidget {
  final List<ChatMessage> messages;
  const ChatUI({super.key, required this.messages});

  @override
  State<ChatUI> createState() => _ChatUIState();
}

class _ChatUIState extends State<ChatUI> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        widget.messages.add(ChatMessage(text: text, isUser: true));
        _isLoading = true;
      });
      _textController.clear();
      _scrollToBottom();

      await Future.delayed(const Duration(seconds: 2));
      const modelResponse =
          "This is a simulated response. You can now implement the real API call to your Vertex AI model.";

      setState(() {
        widget.messages.add(ChatMessage(text: modelResponse, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: widget.messages.length,
                itemBuilder: (context, index) {
                  final message = widget.messages[index];
                  return MessageBubble(
                    message: message,
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.5);
                },
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: LinearProgressIndicator(),
          ),
        _buildTextInputArea(),
      ],
    );
  }

  Widget _buildTextInputArea() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_outlined),
              onPressed: () {
                // TODO: Implement file picking
              },
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                onKey: (event) {
                  if (event.isKeyPressed(LogicalKeyboardKey.enter) &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    _sendMessage();
                  }
                },
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 5,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isLoading ? null : _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.all(12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isExpanded = true;
  late final bool _isLongMessage;
  static const int _maxLength = 300;

  @override
  void initState() {
    super.initState();
    _isLongMessage = widget.message.text.length > _maxLength;
    if (_isLongMessage && widget.message.isUser) {
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.message.isUser;

    final messageText =
        _isExpanded || !isUser || !_isLongMessage
            ? widget.message.text
            : '${widget.message.text.substring(0, _maxLength)}...';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 4.0,
              bottom: 4.0,
              left: isUser ? 10.0 : 0.0,
              right: isUser ? 0.0 : 10.0,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(5),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLongMessage && isUser)
                  _buildIconButton(
                    context,
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                if (widget.message.attachments.isNotEmpty)
                  _buildAttachmentView(context),
                if (widget.message.text.isNotEmpty)
                  SelectableText(
                    messageText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                const SizedBox(height: 8.0),
                _buildActionBar(context, isUser),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: widget.message.attachments.map((file) {
          return Chip(
            label: Text(
              file.split('/').last,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            avatar: const Icon(Icons.attach_file, size: 16),
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: isUser
          ? [
              _buildIconButton(
                context,
                Icons.copy_all_outlined,
                () {
                  Clipboard.setData(ClipboardData(text: widget.message.text));
                },
                color: theme.colorScheme.onPrimaryContainer,
              ),
              _buildIconButton(
                context,
                Icons.edit_outlined,
                () {
                  // TODO: Implement edit
                },
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ]
          : [
              _buildIconButton(context, Icons.copy_all_outlined, () {
                Clipboard.setData(ClipboardData(text: widget.message.text));
              }),
              _buildIconButton(context, Icons.refresh_outlined, () {
                // TODO: Implement regenerate
              }),
            ],
    );
  }

  Widget _buildIconButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onPressed,
      padding: const EdgeInsets.all(8.0),
      constraints: const BoxConstraints(),
      splashRadius: 20.0,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}