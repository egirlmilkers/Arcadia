import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:toastification/toastification.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/logging.dart';
import 'welcome.dart';
import 'md/code_block.dart';
import 'md/highlight.dart';
import '../main.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:mime/mime.dart';

import '../services/chat_history.dart';
import '../services/model.dart' as model_service;
import '../theme/manager.dart';
import '../util.dart';
import 'widgets/thinking_spinner.dart';

/// A widget that displays a chat session, including messages, a text input
/// area, and attachments.
///
/// This widget is responsible for handling user input, sending messages to the
/// Gemini API, and displaying the conversation.
class ChatUI extends StatefulWidget {
  /// The chat session to be displayed.
  final ArcadiaChat chatSession;

  /// The name of the selected model for content generation.
  final model_service.Model selectedModel;

  /// A callback function that is called when a new message is sent.
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
  final Logging _logger = Logging();
  bool _isLoading = false;
  StreamSubscription<GenerateContentResponse>? _streamSubscription;
  List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Cancel any ongoing Gemini service call to prevent memory leaks.
    _streamSubscription?.cancel();
    super.dispose();
  }

  /// Sends a message to the Gemini API.
  ///
  /// This method handles text and attachments, updates the UI optimistically,
  /// and calls the Gemini service to generate a response. It also handles
  /// title generation for new chats.
  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

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
      final attachmentsDir = Directory(p.join(docs.path, 'Arcadia', 'attachments'));
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
      _logger.info('Copied ${attachmentPaths.length} attachments to permanent storage.');
    }

    // Optimistically update the UI
    setState(() {
      widget.chatSession.messages.add(
        ChatMessage(text: text, isUser: true, attachments: attachmentPaths),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    // A new chat is defined by having only one message from the user.
    final bool isNewChat = widget.chatSession.messages.length == 1;

    //
    void revertGivenPrompt() {
      setState(() {
        widget.chatSession.messages.removeLast();
        _textController.text = originalMessage;
        _attachments = originalAttachments;
      });
      _logger.warning('Unsent prompt.');
    }

    try {
      final generationConfig = GenerationConfig(
        thinkingConfig: widget.selectedModel.thinking ? ThinkingConfig(thinkingBudget: -1, includeThoughts: true) : null,
      );

      // prepare safety settings
      final safetySettings = [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.off, null),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.off, null),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.off, null),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.off, null),
      ];

      // generate response with firebase ai
      final model = FirebaseAI.googleAI().generativeModel(
        model: widget.selectedModel.name,
        generationConfig: generationConfig,
        safetySettings: safetySettings,
      );

      // a super quick model that we use to do minimal shit (chat name)
      final titleModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-1.5-flash');

      // Generate title for new chats
      if (isNewChat) {
        _logger.info('New chat detected. Generating title.');
        final titlePrompt =
            'Generate a short, concise header (5 words max) for an ai chat started with this user query:\n\n$originalMessage\n\n[Please do not provide anything else, just the 5 word title. This will show up in a list of multiple user chat sessions so it needs to be easily distiniguishable without the need to open the chat.]';
        final titleResponse = await titleModel.generateContent([Content.text(titlePrompt)]);
        if (titleResponse.text != null) {
          setState(() {
            widget.chatSession.title = titleResponse.text!.replaceAll('"', '').trim();
          });
          _logger.info('Generated new chat title: ${widget.chatSession.title}');
          widget.onNewMessage?.call(widget.chatSession.title);
        } else {
          _logger.warning('Failed to generate chat title.');
        }
      }

      // Construct the full prompt with history and new message
      final prompt = <Content>[];
      for (final message in widget.chatSession.messages) {
        // For previous messages from the model, or user messages with no attachments,
        // we use the standard Content constructor.
        if (!message.isUser || message.attachments.isEmpty) {
          prompt.add(Content(message.isUser ? 'user' : 'model', [TextPart(message.text)]));
        }
        // For the new user message that contains attachments,
        // we use the Content.multi() constructor as shown in the documentation.
        else {
          // Following the docs: text part goes first.
          final parts = <Part>[TextPart(message.text)];

          // Then, add all the image/file attachments.
          for (final path in message.attachments) {
            final mimeType = lookupMimeType(path);
            if (mimeType != null) {
              final bytes = await File(path).readAsBytes();
              parts.add(InlineDataPart(mimeType, bytes));
            }
          }
          // Create the multimodal content part using the correct constructor.
          prompt.add(Content.multi(parts));
        }
      }

      // Add an empty message for the AI response to stream into (cant stream into null)
      setState(() {
        widget.chatSession.messages.add(ChatMessage(text: '', isUser: false, thinkingProcess: ''));
      });
      _scrollToBottom();

      // same as generateContent but gets the stream from it
      final stream = model.generateContentStream(prompt);
      _handleStreamedResponse(stream, isNewChat: isNewChat, revertGivenPrompt: revertGivenPrompt);
    } catch (e, s) {
      // give the user back their prompt if something fails
      revertGivenPrompt();
      setState(() {
        _isLoading = false;
      });
      _logger.error('Error sending message', e, s);
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: const Text("Something went wrong"),
        description: Text(e.toString().replaceFirst("Exception: ", "")),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(left: 8, right: 8),
        autoCloseDuration: const Duration(seconds: 4),
      );
    }
  }

  void _handleStreamedResponse(
    Stream<GenerateContentResponse> stream, {
    bool isNewChat = false,
    VoidCallback? revertGivenPrompt,
  }) {
    bool watchFirstChunk = isNewChat; // once we receive the first chunk, we know nothing failed

    // since prompt didn't fail, we NOW save the new chat
    _streamSubscription = stream.listen(
      (response) {
        if (watchFirstChunk) {
          watchFirstChunk = false; // no longer need to look cus we got it
          _chatHistoryService.saveChat(widget.chatSession);
        }

        final lastMsg = widget.chatSession.messages.last;

        // The model's "thoughts" are streamed during generation
        if (response.thoughtSummary != null) {
          setState(() {
            lastMsg.thinkingProcess = (lastMsg.thinkingProcess ?? '') + response.thoughtSummary!;
          });
        }

        // constantly keep the message up-to-date with stream
        if (response.text != null) {
          setState(() {
            lastMsg.text += response.text!;
          });
          // _scrollToBottom(duration: 500);
        }
      },
      onDone: () async {
        await _chatHistoryService.saveChat(widget.chatSession);
        setState(() {
          _isLoading = false;
        });
        _logger.info('Message stream finished.');
      },
      onError: (e) {
        if (revertGivenPrompt != null) {
          revertGivenPrompt();
        }
        // Remove the empty AI message holder
        if (widget.chatSession.messages.isNotEmpty && !widget.chatSession.messages.last.isUser) {
          widget.chatSession.messages.removeLast();
        }
        setState(() {
          _isLoading = false;
        });
        _logger.error('Error in message stream', e);
        toastification.show(
          type: ToastificationType.error,
          style: ToastificationStyle.flatColored,
          title: const Text("Something went wrong"),
          description: Text(e.toString()),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(left: 8, right: 8),
          autoCloseDuration: const Duration(seconds: 4),
          borderRadius: BorderRadius.circular(100.0),
        );
      },
      cancelOnError: true,
    );
  }

  /// Stops the currently streaming message generation.
  void _stopMessage() {
    _streamSubscription?.cancel();
    setState(() {
      _isLoading = false;
    });
    _logger.info('Stopped message generation.');
  }

  /// Regenerates the response for a given message.
  ///
  /// This method removes the previous AI response and any subsequent messages,
  /// then calls the Gemini service to generate a new response.
  void _regenerateResponse(int messageIndex) async {
    if (messageIndex == 0) {
      // Cannot regenerate the first message in a chat.
      toastification.show(
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        title: const Text("Cannot regenerate the first message."),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(left: 8, right: 8),
        autoCloseDuration: const Duration(seconds: 4),
        borderRadius: BorderRadius.circular(100.0),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      // Remove the AI message and any subsequent messages.
      widget.chatSession.messages.removeRange(messageIndex, widget.chatSession.messages.length);
    });
    _scrollToBottom();
    _logger.info('Regenerating response for message at index $messageIndex.');

    try {
      final generationConfig = GenerationConfig(
        thinkingConfig: widget.selectedModel.thinking ? ThinkingConfig(thinkingBudget: -1, includeThoughts: true) : null,
      );

      // prepare safety settings
      final safetySettings = [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.off, null),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.off, null),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.off, null),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.off, null),
      ];

      // generate response with firebase ai
      final model = FirebaseAI.googleAI().generativeModel(
        model: widget.selectedModel.name,
        generationConfig: generationConfig,
        safetySettings: safetySettings,
      );

      // Construct the full prompt with history and new message
      final prompt = <Content>[];
      for (final message in widget.chatSession.messages) {
        // For previous messages from the model, or user messages with no attachments,
        // we use the standard Content constructor.
        if (!message.isUser || message.attachments.isEmpty) {
          prompt.add(Content(message.isUser ? 'user' : 'model', [TextPart(message.text)]));
        }
        // For the new user message that contains attachments,
        // we use the Content.multi() constructor as shown in the documentation.
        else {
          // Following the docs: text part goes first.
          final parts = <Part>[TextPart(message.text)];

          // Then, add all the image/file attachments.
          for (final path in message.attachments) {
            final mimeType = lookupMimeType(path);
            if (mimeType != null) {
              final bytes = await File(path).readAsBytes();
              parts.add(InlineDataPart(mimeType, bytes));
            }
          }
          // Create the multimodal content part using the correct constructor.
          prompt.add(Content.multi(parts));
        }
      }

      setState(() {
        widget.chatSession.messages.add(ChatMessage(text: '', isUser: false, thinkingProcess: ''));
      });
      _scrollToBottom();

      final stream = model.generateContentStream(prompt);
      _handleStreamedResponse(stream);
    } catch (e, s) {
      setState(() {
        _isLoading = false;
      });
      _logger.error('Error regenerating response', e, s);
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: const Text("Something went wrong"),
        description: Text(e.toString().replaceFirst("Exception: ", "")),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(left: 8, right: 8),
        autoCloseDuration: const Duration(seconds: 4),
      );
    }
  }

  /// Scrolls the chat to the bottom.
  ///
  /// This is typically called after a new message is added to the chat.
  void _scrollToBottom({int? duration}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(
            milliseconds: duration ?? (_scrollController.position.maxScrollExtent / 10).toInt(),
          ),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The main chat area, which is expandable.
        // Expanded(
        // A listener to handle scroll events for a smoother experience.
        // child:
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  clampDouble(
                    _scrollController.offset + event.scrollDelta.dy,
                    0,
                    _scrollController.position.maxScrollExtent,
                  ),
                );
              }
            }
          },
          // If there are no messages, show the welcome UI.
          child: widget.chatSession.messages.isEmpty
              ? const WelcomeUI()
              : Align(
                  // Replaced Center with Align
                  alignment: Alignment.topCenter, // Aligns the child to the bottom
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    // A scrollable column of all messages in the chat session.
                    child: Padding(
                      padding: EdgeInsetsGeometry.only(bottom: 65),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 25),
                        child: Column(
                          children: [
                            for (
                              int index = 0;
                              index < widget.chatSession.messages.length;
                              index++
                            ) ...[
                              Builder(
                                builder: (context) {
                                  final message = widget.chatSession.messages[index];
                                  // Determine if the message is the last one from the user or AI.
                                  final lastUserMessageIndex = widget.chatSession.messages
                                      .lastIndexWhere((m) => m.isUser);
                                  final lastAiMessageIndex = widget.chatSession.messages
                                      .lastIndexWhere((m) => !m.isUser);

                                  final bool isLastUserMessage = index == lastUserMessageIndex;
                                  final bool isLastAiMessage = index == lastAiMessageIndex;

                                  // Each message is displayed in a MessageBubble.
                                  return MessageBubble(
                                    message: message,
                                    isLastUserMessage: isLastUserMessage,
                                    isLastAiMessage: isLastAiMessage,
                                    onMessageEdited: (newText) {
                                      setState(() {
                                        widget.chatSession.messages[index].text = newText;
                                      });
                                      _chatHistoryService.saveChat(widget.chatSession);
                                    },
                                    onRegenerate: () {
                                      _regenerateResponse(index);
                                    },
                                  );
                                },
                              ),
                              if (index < widget.chatSession.messages.length - 1)
                                const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        //),
        // The text input area at the bottom of the screen.
        _buildPromptInputArea(),
      ],
    );
  }

  /// Builds the text input area, including the attach button, text field, and send button.
  Widget _buildPromptInputArea() {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final themeName = themeManager.selectedTheme;

    final inputArea = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display the attachment view if there are any attachments.
        if (_attachments.isNotEmpty)
          AttachmentView(
            attachments: _attachments.map((e) => e.path!).toList(),
            onAttachmentRemoved: (index) {
              setState(() {
                _attachments.removeAt(index);
              });
            },
          ),

        // The main container for the input controls.
        Container(
          color: theme.colorScheme.surface,
          padding: EdgeInsets.only(
            bottom: 8,
            left: 4,
            right: 4,
            top: _attachments.isNotEmpty ? 0 : 8,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // The button for attaching files.
                Tooltip(
                  message: 'Attach files',
                  child: IconButton(
                    icon: const Icon(Icons.attach_file_outlined),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        type: FileType.custom,
                        allowedExtensions: [
                          'jpg', 'jpeg', 'png', 'webp', // Images
                          'mp4', 'webm', 'mkv', 'mov', // Videos
                          'pdf', 'txt', // Documents
                          'mp3',
                          'mpga',
                          'wav',
                          'webm',
                          'm4a',
                          'opus',
                          'aac',
                          'flac',
                          'pcm', // Audio
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

                // The main text input field.
                Expanded(
                  child: Focus(
                    onKeyEvent: (FocusNode node, KeyEvent event) {
                      // Send the message when the user presses Enter without Shift.
                      if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.enter) &&
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
                // The send/stop button.
                Tooltip(
                  message: _isLoading ? 'Stop' : 'Send message',
                  child: IconButton(
                    icon: Icon(_isLoading ? Icons.stop : Icons.send),
                    onPressed: _isLoading ? _stopMessage : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.all(12.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // Center the input area and constrain its width.
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: inputArea),
    );
  }
}

/// A widget that displays a list of attachments.
///
/// This widget is used to show file attachments in the chat input area and
/// within message bubbles. It supports removing attachments.
class AttachmentView extends StatefulWidget {
  /// The list of file paths for the attachments.
  final List<String> attachments;

  /// A callback function that is called when an attachment is removed.
  final Function(int)? onAttachmentRemoved;

  const AttachmentView({super.key, required this.attachments, this.onAttachmentRemoved});

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

  /// Returns an appropriate icon for a given file path based on its extension.
  IconData _getIconForFile(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    switch (extension) {
      // Image file types
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
        return Icons.image_outlined;
      // Video file types
      case '.mp4':
      case '.webm':
      case '.mkv':
      case '.mov':
        return Icons.movie_outlined;
      // Document file types
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.txt':
        return Icons.article_outlined;
      // Audio file types
      case '.mp3':
      case '.wav':
      case '.m4a':
      case '.opus':
      case '.flac':
      case '.aac':
      case '.pcm':
      case '.mpga':
        return Icons.audiotrack_outlined;
      // Default icon for other file types
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there are no attachments, return an empty box.
    if (widget.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // The main container for the attachment view.
    return Container(
      height: 50,
      color: Colors.transparent,
      child: Scrollbar(
        controller: _scrollController,
        thickness: 6,
        thumbVisibility: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          // A horizontal list of attachments.
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: widget.attachments.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final filePath = widget.attachments[index];
              final fileName = p.basenameWithoutExtension(filePath);
              final fileExt = p.extension(filePath);

              // Each attachment is displayed as an InputChip.
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: InputChip(
                  avatar: Icon(_getIconForFile(filePath), size: 18),
                  label: Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(fileName, overflow: TextOverflow.fade, softWrap: false),
                        ),
                        Text(fileExt),
                      ],
                    ),
                  ),
                  // Allow deletion if a callback is provided.
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

/// A widget that displays a single message in the chat.
///
/// This widget handles the display of user and AI messages, including attachments,
/// thinking processes, and action buttons for copying, editing, and regenerating.
class MessageBubble extends StatefulWidget {
  /// The message to be displayed.
  final ChatMessage message;

  /// Whether this is the last message from the user.
  final bool isLastUserMessage;

  /// Whether this is the last message from the AI.
  final bool isLastAiMessage;

  /// A callback function that is called when the message is edited.
  final Function(String) onMessageEdited;

  /// A callback function that is called when the user requests to regenerate the message.
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

class _MessageBubbleState extends State<MessageBubble> with AutomaticKeepAliveClientMixin {
  late final bool _isLongMessage;
  late bool _isExpanded;
  static const int _maxLength = 300;
  bool _hasAnimated = false;
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editingController;
  bool _isSummaryExpanded = false;

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

  // Keep the state of the message bubble alive to preserve animations and state.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isUser = widget.message.isUser;

    // Truncate long messages for a better user experience.
    final messageText = _isExpanded || !isUser || !_isLongMessage
        ? widget.message.text
        : (widget.message.text.length > _maxLength
              ? '${widget.message.text.substring(0, _maxLength)}...'
              : widget.message.text);

    // Show action buttons on hover or for the last message in the chat.
    final bool shouldShowButtons =
        (isUser && widget.isLastUserMessage) || (!isUser && widget.isLastAiMessage) || _isHovering;

    if (_isEditing) {
      return _buildEditingView(context);
    }

    // The main message bubble widget.
    Widget messageWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Display attachments if they exist.
            if (widget.message.attachments.isNotEmpty)
              AttachmentView(attachments: widget.message.attachments),

            // The container for the message content.
            Container(
              margin: EdgeInsets.only(
                top: 4.0,
                bottom: 4.0,
                left: isUser ? 40.0 : 0.0,
                right: isUser ? 0.0 : 40.0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isUser ? theme.colorScheme.secondary : Colors.transparent,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: isUser
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  // Action bar for AI messages.
                  if (!isUser) ...[
                    AnimatedOpacity(
                      opacity: shouldShowButtons ? 1.0 : 0.0,
                      duration: 200.ms,
                      child: _buildActionBar(context, isUser),
                    ),
                    const SizedBox(width: 8.0),
                  ],
                  // The main content of the message.
                  Flexible(
                    child: Column(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display the thinking process if it exists.
                        if (!isUser && widget.message.thinkingProcess != null) ...[
                          _buildThinkingProcess(context),
                        ],
                        // The message text, rendered as Markdown.
                        SelectionArea(
                          selectionControls: materialTextSelectionControls,
                          child: GptMarkdown(
                            messageText,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isUser
                                  ? theme.colorScheme.onSecondary
                                  : theme.colorScheme.onSurface,
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
                  // Action bar for user messages.
                  if (isUser) ...[
                    const SizedBox(width: 8.0),
                    AnimatedOpacity(
                      opacity: shouldShowButtons ? 1.0 : 0.0,
                      duration: 200.ms,
                      child: _buildActionBar(context, isUser),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Animate the message bubble when it first appears.
    if (!_hasAnimated) {
      messageWidget = messageWidget
          .animate(
            onComplete: (controller) {
              setState(() {
                _hasAnimated = true;
              });
            },
          )
          .fadeIn(duration: 500.ms);
    }

    return messageWidget;
  }

  /// Builds the widget that displays the AI's thinking process.
  Widget _buildThinkingProcess(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      // Animate the width based on the state variable.
      width: _isSummaryExpanded ? 600 : 170,
      child: Material(
        // material so the colors dont clash with the expansion material
        animateColor: true,
        color: _isSummaryExpanded
            ? theme.colorScheme.inversePrimary
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(25),
        // clips the corners of children as well
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            dense: true,
            // When the tile is toggled, update the state variable.
            onExpansionChanged: (expanded) {
              setState(() {
                _isSummaryExpanded = expanded;
              });
            },
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            title: Text(
              'Thinking Summary',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              overflow: TextOverflow.fade,
              maxLines: 1,
            ),
            collapsedIconColor: theme.colorScheme.onPrimaryContainer,
            iconColor: theme.colorScheme.onPrimaryContainer,
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
        ),
      ),
    );
  }

  /// Builds the action bar with buttons for copying, editing, etc.
  Widget _buildActionBar(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    final onSecondary = theme.colorScheme.onSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: isUser
          ? [
              // Expand/collapse button for long messages.
              if (_isLongMessage)
                Tooltip(
                  message: _isExpanded ? 'Collapse' : 'Expand',
                  child: _buildIconButton(
                    context,
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    () => setState(() => _isExpanded = !_isExpanded),
                    color: onSecondary,
                  ),
                ),
              // Copy button.
              Tooltip(
                message: 'Copy',
                child: _buildIconButton(context, Icons.copy_all_outlined, () {
                  Clipboard.setData(ClipboardData(text: widget.message.text));
                  showCopiedToast(context, theme.colorScheme);
                }, color: onSecondary),
              ),
              // Edit button.
              Tooltip(
                message: 'Edit',
                child: _buildIconButton(context, Icons.edit_outlined, () {
                  setState(() {
                    _isEditing = true;
                  });
                }, color: onSecondary),
              ),
            ]
          : [
              // Copy button for AI messages.
              Tooltip(
                message: 'Copy',
                child: _buildIconButton(context, Icons.copy_all_outlined, () {
                  Clipboard.setData(ClipboardData(text: widget.message.text));
                  showCopiedToast(context, theme.colorScheme);
                }),
              ),
              // Regenerate button for AI messages.
              Tooltip(
                message: 'Regenerate',
                child: _buildIconButton(context, Icons.refresh_outlined, widget.onRegenerate),
              ),
            ],
    );
  }

  /// A helper method for building icon buttons in the action bar.
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

  /// Builds the view for editing a message.
  Widget _buildEditingView(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          // The text field for editing the message.
          TextField(
            controller: _editingController,
            autofocus: true,
            maxLines: null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          // Action buttons for saving or cancelling the edit.
          Row(
            spacing: 8,
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
