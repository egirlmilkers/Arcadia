import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:toastification/toastification.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'welcome.dart';
import 'md/code_block.dart';
import 'md/highlight.dart';
import '../main.dart';
import '../services/chat_history.dart';
import '../services/gemini.dart';
import '../theme/manager.dart';
import '../util.dart';
import 'widgets/thinking_spinner.dart';

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
  List<PlatformFile> _attachments = [];

  @override
  void dispose() {
    _geminiService?.cancel();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final originalMessage = text;
    final originalAttachments = List<PlatformFile>.from(_attachments);

    _textController.clear();
    setState(() {
      _attachments.clear();
    });

    // Copy attachments to a permanent location
    final List<String> attachmentPaths = [];
    if (originalAttachments.isNotEmpty) {
      final docs = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory(
        p.join(docs.path, 'Arcadia', 'attachments'),
      );
      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }

      for (final file in originalAttachments) {
        if (file.path != null) {
          final newPath = p.join(attachmentsDir.path, file.name);
          await File(file.path!).copy(newPath);
          attachmentPaths.add(newPath);
        }
      }
    }

    setState(() {
      widget.chatSession.messages.add(
        ChatMessage(text: text, isUser: true, attachments: attachmentPaths),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    // A new chat is defined by having only one message from the user
    final bool isNewChat = widget.chatSession.messages.length == 1;

    // A local function to clean up the UI on a failed attempt (either cancel or error)
    void revertOptimisticUI() {
      setState(() {
        widget.chatSession.messages.removeLast();
        _textController.text = originalMessage;
        _attachments = originalAttachments;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key');
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("API key not set. Please set it in settings.");
      }

      final titleService = GeminiService(apiKey: apiKey);
      final contentService = GeminiService(apiKey: apiKey);
      _geminiService = contentService;

      Map<String, dynamic> modelResponse;
      if (isNewChat) {
        final prompt =
            'Generate a short, concise title (5 words max) for an ai chat started with this user query:\n\n$originalMessage';
        final titleFuture = titleService.generateContent([
          ChatMessage(text: prompt, isUser: true),
        ], 'gemini-1.5-flash-latest');

        final contentFuture = contentService.generateContent(
          widget.chatSession.messages,
          widget.selectedModel,
        );

        final results = await Future.wait([titleFuture, contentFuture]);
        final newTitleResponse = results[0];
        modelResponse = results[1];

        if (newTitleResponse['error'] == null) {
          setState(() {
            widget.chatSession.title = newTitleResponse['text']
                .replaceAll('"', '')
                .trim();
          });
        }
      } else {
        modelResponse = await contentService.generateContent(
          widget.chatSession.messages,
          widget.selectedModel,
        );
      }

      // 1. Check for cancellation first.
      if (modelResponse['text'] == GeminiService.cancelledResponse) {
        // Treat user cancellation not as an error.
        // Clean up the UI and exit gracefully.
        revertOptimisticUI();
        return;
      }

      // 2. Check for actual errors from the API.
      if (modelResponse['error'] != null) {
        // This is a real error. Throw an exception to be caught below.
        throw Exception(modelResponse['error']);
      }

      // 3. If neither of the above, it's a success.
      setState(() {
        widget.chatSession.messages.add(
          ChatMessage(
            text: modelResponse['text'],
            isUser: false,
            thinkingProcess: modelResponse['thinkingProcess'],
          ),
        );
      });
      _scrollToBottom();

      await _chatHistoryService.saveChat(widget.chatSession);
      if (isNewChat) {
        widget.onNewMessage?.call(widget.chatSession.title);
      }
    } catch (e) {
      revertOptimisticUI();

      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: const Text("Something went wrong"),
        description: Text(e.toString().replaceFirst("Exception: ", "")),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(left: 8, right: 8),
        autoCloseDuration: const Duration(seconds: 4),
        animationBuilder: (context, animation, alignment, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        borderRadius: BorderRadius.circular(100.0),
        showProgressBar: true,
        dragToClose: true,
      );
    } finally {
      // ensuring the loading indicator is turned off
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

  void _regenerateResponse(int messageIndex) async {
    if (messageIndex == 0) {
      toastification.show(
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        title: const Text("Cannot regenerate the first message."),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(left: 8, right: 8),
        autoCloseDuration: const Duration(seconds: 4),
        borderRadius: BorderRadius.circular(100.0),
        showProgressBar: true,
        dragToClose: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      // Remove the AI message and any subsequent messages
      widget.chatSession.messages.removeRange(
        messageIndex,
        widget.chatSession.messages.length,
      );
    });
    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key');
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("API key not set. Please set it in settings.");
      }

      final contentService = GeminiService(apiKey: apiKey);
      _geminiService = contentService;

      final modelResponse = await contentService.generateContent(
        widget.chatSession.messages,
        widget.selectedModel,
      );

      if (modelResponse['text'] == GeminiService.cancelledResponse) {
        return; // User cancelled
      }

      if (modelResponse['error'] != null) {
        throw Exception(modelResponse['error']);
      }

      setState(() {
        widget.chatSession.messages.add(
          ChatMessage(
            text: modelResponse['text'],
            isUser: false,
            thinkingProcess: modelResponse['thinkingProcess'],
          ),
        );
      });
      _scrollToBottom();

      await _chatHistoryService.saveChat(widget.chatSession);
    } catch (e) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: const Text("Something went wrong"),
        description: Text(e.toString().replaceFirst("Exception: ", "")),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(left: 8, right: 8),
        autoCloseDuration: const Duration(seconds: 4),
        animationBuilder: (context, animation, alignment, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        borderRadius: BorderRadius.circular(100.0),
        showProgressBar: true,
        dragToClose: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(
                    _scrollController.offset + event.scrollDelta.dy,
                  );
                }
              }
            },
            child: widget.chatSession.messages.isEmpty
                ? const WelcomeUI()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: widget.chatSession.messages.length,
                        itemBuilder: (context, index) {
                          final message = widget.chatSession.messages[index];
                          final lastUserMessageIndex = widget
                              .chatSession
                              .messages
                              .lastIndexWhere((m) => m.isUser);
                          final lastAiMessageIndex = widget.chatSession.messages
                              .lastIndexWhere((m) => !m.isUser);

                          final bool isLastUserMessage =
                              index == lastUserMessageIndex;
                          final bool isLastAiMessage =
                              index == lastAiMessageIndex;

                          return MessageBubble(
                            message: message,
                            isLastUserMessage: isLastUserMessage,
                            isLastAiMessage: isLastAiMessage,
                            onMessageEdited: (newText) {
                              setState(() {
                                widget.chatSession.messages[index].text =
                                    newText;
                              });
                              _chatHistoryService.saveChat(widget.chatSession);
                            },
                            onRegenerate: () {
                              _regenerateResponse(index);
                            },
                          );
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 20);
                        },
                      ),
                    ),
                  ),
          ),
        ),
        _buildTextInputArea(),
      ],
    );
  }

  Widget _buildTextInputArea() {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final themeName = themeManager.selectedTheme;

    final inputArea = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachments.isNotEmpty)
          AttachmentView(
            attachments: _attachments.map((e) => e.path!).toList(),
            onAttachmentRemoved: (index) {
              setState(() {
                _attachments.removeAt(index);
              });
            },
          ),

        Container(
          padding: EdgeInsets.only(
            bottom: 8,
            left: 4,
            right: 4,
            top: _attachments.isNotEmpty ? 0 : 8,
          ),
          child: SafeArea(
            top: false, // SafeArea is only needed for the bottom.
            child: Row(
              children: [
                Tooltip(
                  message: 'Attach files',
                  child: IconButton(
                    icon: const Icon(Icons.attach_file_outlined),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
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
                        setState(() {
                          _attachments.addAll(result.files);
                        });
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
                      readOnly: _isLoading,
                      decoration: InputDecoration(
                        hintText: _isLoading ? null : 'Ask $themeName',
                        hint: _isLoading ? const ThinkingSpinner() : null,
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
        ),
      ],
      //   ),
      // ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: inputArea,
      ),
    );
  }
}

class AttachmentView extends StatefulWidget {
  final List<String> attachments;
  final Function(int)? onAttachmentRemoved;

  const AttachmentView({
    super.key,
    required this.attachments,
    this.onAttachmentRemoved,
  });

  @override
  State<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<AttachmentView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  IconData _getIconForFile(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
        return Icons.image_outlined;
      case '.mp4':
      case '.webm':
      case '.mkv':
      case '.mov':
        return Icons.movie_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.txt':
        return Icons.article_outlined;
      case '.mp3':
      case '.wav':
      case '.m4a':
      case '.opus':
      case '.flac':
      case '.aac':
      case '.pcm':
      case '.mpga':
        return Icons.audiotrack_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    //final theme = Theme.of(context);

    if (widget.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      color: Colors.transparent,
      child: Scrollbar(
        controller: _scrollController,
        thickness: 6,
        thumbVisibility: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: widget.attachments.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final filePath = widget.attachments[index];
              final fileName = p.basenameWithoutExtension(filePath);
              final fileExt = p.extension(filePath);

              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: InputChip(
                  avatar: Icon(_getIconForFile(filePath), size: 18),
                  // disabledColor: theme.colorScheme.onPrimary,
                  // labelStyle: widget.onAttachmentRemoved == null ? TextStyle(
                  //   color: theme.colorScheme.primary,
                  // ) : null,
                  label: Container(
                    constraints: BoxConstraints(maxWidth: 120),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            fileName,
                            overflow: TextOverflow.fade,
                            softWrap: false, // good practice with ellipsis
                          ),
                        ),
                        Text(fileExt), // always visible
                      ],
                    ),
                  ),
                  onDeleted: widget.onAttachmentRemoved != null
                      ? () => widget.onAttachmentRemoved!(index)
                      : null,
                  deleteIcon: widget.onAttachmentRemoved != null
                      ? const Icon(Icons.cancel, size: 18)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isLastUserMessage;
  final bool isLastAiMessage;
  final Function(String) onMessageEdited;
  final VoidCallback onRegenerate;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLastUserMessage = false,
    this.isLastAiMessage = false,
    required this.onMessageEdited,
    required this.onRegenerate,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  late final bool _isLongMessage;
  late bool _isExpanded;
  static const int _maxLength = 300;
  bool _hasAnimated = false;
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editingController;

  @override
  void initState() {
    super.initState();
    _isLongMessage = widget.message.text.length > _maxLength;
    _isExpanded = !(_isLongMessage && widget.message.isUser);
    _editingController = TextEditingController(text: widget.message.text);
  }

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isUser = widget.message.isUser;

    final messageText = _isExpanded || !isUser || !_isLongMessage
        ? widget.message.text
        : (widget.message.text.length > _maxLength
              ? '${widget.message.text.substring(0, _maxLength)}...'
              : widget.message.text);

    final bool shouldShowButtons =
        (isUser && widget.isLastUserMessage) ||
        (!isUser && widget.isLastAiMessage) ||
        _isHovering;

    if (_isEditing) {
      return _buildEditingView(context);
    }

    Widget messageWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (widget.message.attachments.isNotEmpty)
              AttachmentView(attachments: widget.message.attachments),

            Container(
              margin: EdgeInsets.only(
                top: 4.0,
                bottom: 4.0,
                left: isUser ? 40.0 : 0.0,
                right: isUser ? 0.0 : 40.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
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
                maxWidth: isUser
                    ? 500
                    : MediaQuery.of(context).size.width * 0.75,
                minWidth: 150,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: isUser
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    AnimatedOpacity(
                      opacity: shouldShowButtons ? 1.0 : 0.0,
                      duration: 200.ms,
                      child: _buildActionBar(context, isUser),
                    ),
                    const SizedBox(width: 8.0),
                  ],
                  Flexible(
                    child: Column(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser && widget.message.thinkingProcess != null)
                          _buildThinkingProcess(context),
                        SelectionArea(
                          //focusNode: FocusNode(),
                          selectionControls: materialTextSelectionControls,
                          child: GptMarkdown(
                            messageText,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isUser
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              // fontWeight: isUser ? FontWeight.w500 : null,
                              // letterSpacing: isUser ? 0 : null,
                              // wordSpacing: isUser ? 1.5 : null,
                            ),
                            codeBuilder: (context, name, code, closed) {
                              return CodeBlock(
                                language: name,
                                code: code,
                                brightness: Theme.of(context).brightness,
                              );
                            },
                            highlightBuilder: (context, text, style) {
                              return Highlight(text: text);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUser) const SizedBox(width: 8.0),
                  if (isUser)
                    AnimatedOpacity(
                      opacity: shouldShowButtons ? 1.0 : 0.0,
                      duration: 200.ms,
                      child: _buildActionBar(context, isUser),
                    ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildThinkingProcess(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        tilePadding: EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: EdgeInsets.all(10),
        title: Text(
          'Thinking Summary',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          GptMarkdown(
            widget.message.thinkingProcess!,
            style: theme.textTheme.bodyLarge?.copyWith(),
            codeBuilder: (context, name, code, closed) {
              return CodeBlock(
                language: name,
                code: code,
                brightness: Theme.of(context).brightness,
              );
            },
            highlightBuilder: (context, text, style) {
              return Highlight(text: text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    final onPrimaryContainer = theme.colorScheme.onPrimaryContainer;

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
                  showCopiedToast(context, theme.colorScheme);
                }, color: onPrimaryContainer),
              ),
              Tooltip(
                message: 'Edit',
                child: _buildIconButton(context, Icons.edit_outlined, () {
                  setState(() {
                    _isEditing = true;
                  });
                }, color: onPrimaryContainer),
              ),
            ]
          : [
              Tooltip(
                message: 'Copy',
                child: _buildIconButton(context, Icons.copy_all_outlined, () {
                  Clipboard.setData(ClipboardData(text: widget.message.text));
                  showCopiedToast(context, theme.colorScheme);
                }),
              ),
              Tooltip(
                message: 'Regenerate',
                child: _buildIconButton(
                  context,
                  Icons.refresh_outlined,
                  widget.onRegenerate,
                ),
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

  Widget _buildEditingView(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          TextField(
            controller: _editingController,
            autofocus: true,
            maxLines: null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _editingController.text = widget.message.text;
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8.0),
              FilledButton(
                onPressed: () {
                  widget.onMessageEdited(_editingController.text);
                  setState(() {
                    _isEditing = false;
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
