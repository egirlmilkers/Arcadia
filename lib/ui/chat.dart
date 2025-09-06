import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:toastification/toastification.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/chat_history.dart';
import '../services/gemini.dart';
import '../theme/manager.dart';

class ChatUI extends StatefulWidget {
  final ChatSession chatSession;
  final String selectedModel;
  final Function(String)? onNewMessage;
  const ChatUI({
    super.key,
    required this.chatSession,
    required this.selectedModel,
    this.onNewMessage,
  });

  @override
  State<ChatUI> createState() => _ChatUIState();
}

class _ChatUIState extends State<ChatUI> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  bool _isLoading = false;
  GeminiService? _geminiService;

  @override
  void dispose() {
    _geminiService?.cancel();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        widget.chatSession.messages.add(ChatMessage(text: text, isUser: true));
        _isLoading = true;
      });
      _textController.clear();
      _scrollToBottom();

      final bool isNewChat = widget.chatSession.isNew;
      if (isNewChat) {
        widget.chatSession.generateTitleFromFirstMessage();
        widget.chatSession.isNew = false;
      }

      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key');
      if (apiKey == null || apiKey == "") {
        setState(() {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flatColored,
            title: const Text("API key not set"),
            description: const Text("Please set it in settings."),
            alignment: Alignment.bottomCenter,
            padding: EdgeInsets.only(left: 8, right: 8),
            autoCloseDuration: const Duration(seconds: 3, milliseconds: 300),
            animationBuilder: (context, animation, alignment, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            borderRadius: BorderRadius.circular(100.0),
            showProgressBar: true,
            dragToClose: true,
            foregroundColor: Colors.red,
            backgroundColor: const Color.fromARGB(255, 255, 97, 97),
          );
          _isLoading = false;
        });
        return;
      }

      _geminiService = GeminiService(apiKey: apiKey);
      final modelResponse = await _geminiService!.generateContent(
        widget.chatSession.messages,
        widget.selectedModel,
      );

      if (modelResponse != GeminiService.cancelledResponse) {
        setState(() {
          widget.chatSession.messages.add(
            ChatMessage(text: modelResponse, isUser: false),
          );
        });
        _scrollToBottom();

        if (isNewChat) {
          final chats = await _chatHistoryService.loadChats();
          chats.insert(0, widget.chatSession);
          await _chatHistoryService.saveChats(chats);
          widget.onNewMessage?.call(widget.chatSession.title);
        } else {
          final chats = await _chatHistoryService.loadChats();
          final index = chats.indexWhere(
            (chat) => chat.id == widget.chatSession.id,
          );
          if (index != -1) {
            chats[index] = widget.chatSession;
            await _chatHistoryService.saveChats(chats);
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _stopMessage() {
    _geminiService?.cancel();
    setState(() {
      _isLoading = false;
    });
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
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: widget.chatSession.messages.length,
                itemBuilder: (context, index) {
                  final message = widget.chatSession.messages[index];
                  return MessageBubble(message: message);
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
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final themeName = themeManager.selectedTheme;

    final inputArea = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            Tooltip(
              message: 'Attach files',
              child: IconButton(
                icon: const Icon(Icons.attach_file_outlined),
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: [
                      // Images
                      'jpg', 'jpeg', 'png', 'webp',
                      // Videos
                      'mp4', 'webm', 'mkv', 'mov',
                      // Documents
                      'pdf', 'txt',
                      // Audio
                      'mp3',
                      'mpga',
                      'wav',
                      'webm',
                      'm4a',
                      'opus',
                      'aac',
                      'flac',
                      'pcm',
                    ],
                  );
                  if (result != null) {
                    // TODO: Handle picked files
                  }
                },
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Focus(
                onKeyEvent: (FocusNode node, KeyEvent event) {
                  if (HardwareKeyboard.instance.isLogicalKeyPressed(
                        LogicalKeyboardKey.enter,
                      ) &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    if (event is KeyDownEvent) {
                      _sendMessage();
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Ask $themeName',
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
            Tooltip(
              message: _isLoading ? 'Stop' : 'Send message',
              child: IconButton(
                icon: Icon(_isLoading ? Icons.stop : Icons.send),
                onPressed: _isLoading ? _stopMessage : _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.all(12.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: inputArea,
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
  late final bool _isLongMessage;
  late bool _isExpanded;
  static const int _maxLength = 300;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _isLongMessage = widget.message.text.length > _maxLength;
    _isExpanded = !(_isLongMessage && widget.message.isUser);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.message.isUser;

    final messageText = _isExpanded || !isUser || !_isLongMessage
        ? widget.message.text
        : '${widget.message.text.substring(0, _maxLength)}...';

    Widget messageWidget = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4.0,
          bottom: 4.0,
          left: isUser ? 40.0 : 0.0,
          right: isUser ? 0.0 : 40.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: isUser
              ? const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(5),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
        ),
        constraints: BoxConstraints(
          maxWidth: isUser ? 500 : MediaQuery.of(context).size.width * 0.75,
          minWidth: 150,
        ),
        // --- START OF CHANGES ---
        // 1. Wrap the Row in an IntrinsicWidth widget.
        // This makes the child size itself to its natural width, while still
        // respecting the parent Container's minWidth constraint.
        child: IntrinsicWidth(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            // 2. Use MainAxisAlignment.spaceBetween for the user message.
            // This pushes the text and the action buttons to opposite ends
            // when there is extra space available (i.e., when minWidth is active).
            // For the other message type, we keep the original packing behavior.
            mainAxisAlignment: isUser
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              if (!isUser) _buildActionBar(context, isUser),
              if (!isUser) const SizedBox(width: 8.0),
              // 3. Keep the text column inside a Flexible widget.
              // This is still crucial! It ensures that long text will wrap
              // correctly instead of causing a pixel overflow.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.message.text.isNotEmpty)
                      SelectableText(
                        messageText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isUser
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
              if (isUser) _buildActionBar(context, isUser),
            ],
          ),
        ),
        // --- END OF CHANGES ---
      ),
    );

    if (!_hasAnimated) {
      messageWidget = messageWidget
          .animate(
            onComplete: (controller) {
              setState(() {
                _hasAnimated = true;
              });
            },
          )
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.5);
    }

    return messageWidget;
  }

  Widget _buildActionBar(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    final onPrimaryContainer = theme.colorScheme.onPrimaryContainer;
    final tertiaryContainer = theme.colorScheme.tertiaryContainer;
    final onTertiaryContainer = theme.colorScheme.onTertiaryContainer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: isUser
          ? [
              if (_isLongMessage)
                Tooltip(
                  message: _isExpanded ? 'Collapse' : 'Expand',
                  child: _buildIconButton(
                    context,
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    () => setState(() => _isExpanded = !_isExpanded),
                    color: onPrimaryContainer,
                  ),
                ),
              Tooltip(
                message: 'Copy',
                child: _buildIconButton(context, Icons.copy_all_outlined, () {
                  Clipboard.setData(ClipboardData(text: widget.message.text));
                  toastification.show(
                    context: context,
                    type: ToastificationType.success,
                    style: ToastificationStyle.simple,
                    title: const Text("Copied to clipboard!"),
                    alignment: Alignment.topCenter,
                    padding: EdgeInsets.only(left: 8, right: 8),
                    backgroundColor: tertiaryContainer,
                    foregroundColor: onTertiaryContainer,
                    autoCloseDuration: const Duration(
                      seconds: 1,
                      milliseconds: 300,
                    ),
                    animationBuilder: (context, animation, alignment, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    borderRadius: BorderRadius.circular(100.0),
                    boxShadow: highModeShadow,
                    closeButton: const ToastCloseButton(
                      showType: CloseButtonShowType.none,
                    ),
                    dragToClose: true,
                    borderSide: BorderSide(color: Colors.transparent),
                  );
                }, color: onPrimaryContainer),
              ),
              Tooltip(
                message: 'Edit',
                child: _buildIconButton(context, Icons.edit_outlined, () {
                  // TODO: Implement edit
                }, color: onPrimaryContainer),
              ),
            ]
          : [
              Tooltip(
                message: 'Copy',
                child: _buildIconButton(context, Icons.copy_all_outlined, () {
                  Clipboard.setData(ClipboardData(text: widget.message.text));
                  toastification.show(
                    context: context,
                    type: ToastificationType.success,
                    style: ToastificationStyle.simple,
                    title: const Text("Copied to clipboard!"),
                    alignment: Alignment.topCenter,
                    padding: EdgeInsets.only(left: 8, right: 8),
                    backgroundColor: tertiaryContainer,
                    foregroundColor: onTertiaryContainer,
                    autoCloseDuration: const Duration(
                      seconds: 1,
                      milliseconds: 300,
                    ),
                    animationBuilder: (context, animation, alignment, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    borderRadius: BorderRadius.circular(100.0),
                    boxShadow: highModeShadow,
                    closeButton: const ToastCloseButton(
                      showType: CloseButtonShowType.none,
                    ),
                    dragToClose: true,
                    borderSide: BorderSide(color: Colors.transparent),
                  );
                }),
              ),
              Tooltip(
                message: 'Regenerate',
                child: _buildIconButton(context, Icons.refresh_outlined, () {
                  // TODO: Implement regenerate
                }),
              ),
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
      padding: const EdgeInsets.all(6.0),
      constraints: const BoxConstraints(),
      splashRadius: 20.0,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
