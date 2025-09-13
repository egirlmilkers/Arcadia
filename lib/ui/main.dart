import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../services/chat_history.dart';
import '../services/logging.dart';
import '../services/model.dart';
import '../theme/manager.dart';
import 'chat.dart';
import 'nav.dart';
import 'welcome.dart';

/// The main UI of the application, which orchestrates the different parts of
/// the screen, including the side navigation, chat view, and app bar.
class MainUI extends StatefulWidget {
  const MainUI({super.key});

  @override
  State<MainUI> createState() => _MainUIState();
}

/// The state for the [MainUI] widget.
///
/// This class manages the active chat session, chat history, and the state
/// of the side navigation bar.
class _MainUIState extends State<MainUI> {
  /// The currently active chat session.
  ArcadiaChat? _activeChat;

  /// The list of all chat sessions.
  List<ArcadiaChat> _chatHistory = [];

  /// The service for managing chat history.
  final ChatHistoryService _chatHistoryService = ChatHistoryService();

  /// Whether the side navigation bar is pinned open.
  bool _isPinned = true;

  /// Whether the mouse is hovering over the side navigation bar.
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _loadPinState();
    _startNewChat();
  }

  /// Loads the pinned state of the side navigation bar from shared preferences.
  void _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPinned = prefs.getBool('isPinned') ?? true;
    });
  }

  /// Saves the pinned state of the side navigation bar to shared preferences.
  void _savePinState(bool isPinned) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isPinned', isPinned);
    Logging().info('Saved pin state: $isPinned');
  }

  /// Loads the chat history from the chat history service.
  Future<void> _loadChatHistory() async {
    _chatHistory = await _chatHistoryService.loadChats();
  }

  /// Starts a new chat session.
  void _startNewChat() {
    setState(() {
      _activeChat = ArcadiaChat(
        title: 'New Chat',
        messages: [],
        version: appVersion!,
      );
    });
    Logging().info('Started new chat');
  }

  /// Deletes a chat session.
  void _deleteChat(ArcadiaChat chat) async {
    if (_activeChat?.id == chat.id) {
      _activeChat = null;
    }
    await _chatHistoryService.deleteChat(chat);
    await _loadChatHistory();
    setState(() {});
    Logging().info('Deleted chat with ID: ${chat.id}');
  }

  /// Archives a chat session.
  void _archiveChat(ArcadiaChat chat) async {
    if (_activeChat?.id == chat.id) {
      _activeChat = null;
    }
    await _chatHistoryService.archiveChat(chat);
    await _loadChatHistory();
    setState(() {});
    Logging().info('Archived chat with ID: ${chat.id}');
  }

  /// Renames a chat session.
  void _renameChat(ArcadiaChat chat, String newTitle) async {
    final activeChatId = _activeChat?.id;
    await _chatHistoryService.renameChat(chat, newTitle);
    await _loadChatHistory();

    if (activeChatId == chat.id) {
      try {
        _activeChat = _chatHistory.firstWhere((c) => c.id == activeChatId);
      } catch (e) {
        _activeChat = null;
        Logging().warning('Failed to find renamed chat in history', e);
      }
    }
    setState(() {});
    Logging().info('Renamed chat with ID: ${chat.id} to "$newTitle"');
  }

  /// Exports a chat session to a JSON file.
  Future<File?> _exportChat(ArcadiaChat chat) async {
    final logger = Logging();
    if (await Permission.storage.status.isGranted) {
      final downloadsDir = await getDownloadsDirectory();

      final chatMessages = chat.messages.map((message) {
        return {
          "role": message.isUser ? "user" : "model",
          "content": message.text,
        };
      }).toList();

      final json = {"messages": chatMessages};

      String? savePath = await FilePicker.platform.saveFile(
        fileName: '${chat.title}.json',
        allowedExtensions: ['json'],
        initialDirectory: downloadsDir.toString(),
      );

      if (savePath == null) {
        logger.info('Chat export cancelled by user.');
        return null;
      }
      logger.info('Exporting chat "${chat.title}" to $savePath');
      return await File(savePath).writeAsBytes(utf8.encode(jsonEncode(json)));
    } else {
      logger.warning('Storage permission not granted. Cannot export chat.');
      return null;
    }
  }

  /// Selects a chat session to be the active one.
  void _selectChat(ArcadiaChat chat) {
    setState(() {
      _activeChat = chat;
    });
    Logging().info('Selected chat with ID: ${chat.id}');
  }

  /// Resets the view to the home screen by clearing the active chat.
  void _resetToHome() {
    setState(() {
      _activeChat = null;
    });
    Logging().info('Reset to home screen');
  }

  /// Toggles the pinned state of the side navigation bar.
  void _toggleSidebar() {
    setState(() {
      _isPinned = !_isPinned;
      _savePinState(_isPinned);
    });
  }

  /// Handles mouse hover events on the side navigation bar to expand or
  /// collapse it when it's not pinned.
  void _handleHover(bool hover) {
    if (!_isPinned) {
      setState(() {
        _isHovering = hover;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme and model managers from the provider.
    final themeManager = context.watch<ThemeManager>();
    final modelManager = context.watch<ModelManager>();
    final theme = Theme.of(context);

    // Show a loading indicator while the models are being loaded.
    if (modelManager.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine the gradient colors for the app bar title.
    final gradientColors =
        themeManager.currentTheme?.gradientColors ??
        [theme.colorScheme.primary, theme.colorScheme.tertiary];
    // Determine whether the side navigation should be expanded.
    final bool isEffectivelyExpanded = _isPinned || _isHovering;

    return Scaffold(
      // Use a Stack to overlay the side navigation on top of the main content.
      body: Stack(
        children: [
          // The main content area, which is padded based on the sidebar state.
          AnimatedPadding(
            duration: 200.ms,
            padding: EdgeInsets.only(left: _isPinned ? 280 : 74),
            child: Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.transparent,
              // The app bar at the top of the screen.
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                // The title of the app, which also acts as a home button.
                title: GestureDetector(
                  onTap: _resetToHome,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      themeManager.selectedTheme,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // makes a gradient app bar background
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 1),
                        theme.colorScheme.surface.withValues(alpha: 0.8),
                        theme.colorScheme.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                // The actions on the right side of the app bar.
                actions: [
                  // The model selection dropdown.
                  if (!modelManager.loading)
                    Center(
                      child: Tooltip(
                        message: "Choose your model",
                        child: Builder(
                          builder: (BuildContext context) {
                            return Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  final RenderBox button =
                                      context.findRenderObject() as RenderBox;
                                  final RenderBox overlay =
                                      Overlay.of(
                                            context,
                                          ).context.findRenderObject()
                                          as RenderBox;

                                  // Calculate the position of the dropdown menu.
                                  final Rect buttonRect = Rect.fromPoints(
                                    button.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlay,
                                    ),
                                    button.localToGlobal(
                                      button.size.bottomRight(Offset.zero),
                                      ancestor: overlay,
                                    ),
                                  );

                                  final Rect shiftedButtonRect = buttonRect
                                      .translate(-110.0, 0.0);

                                  final RelativeRect position =
                                      RelativeRect.fromRect(
                                        shiftedButtonRect,
                                        Offset.zero & overlay.size,
                                      );

                                  // Show the dropdown menu.
                                  showMenu<Model>(
                                    context: context,
                                    position: position,
                                    menuPadding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    items: modelManager.models.map((
                                      Model model,
                                    ) {
                                      return PopupMenuItem<Model>(
                                        value: model,
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(model.displayName),
                                            Text(
                                              model.subtitle,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ).then((Model? value) {
                                    if (value != null) {
                                      modelManager.setSelectedModel(value);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 8,
                                    top: 8,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        modelManager.selectedModel.displayName,
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                ],
              ),
              // The body of the scaffold, which contains the chat UI.
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    // An animated switcher to transition between the welcome screen and the chat UI.
                    child: AnimatedSwitcher(
                      duration: 200.ms,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      // If there is no active chat, show the welcome UI.
                      child: _activeChat == null
                          ? const WelcomeUI()
                          // Otherwise, show the chat UI.
                          : ChatUI(
                              key: ValueKey(_activeChat!.id),
                              chatSession: _activeChat!,
                              selectedModel: modelManager.selectedModel,
                              onNewMessage: (String title) async {
                                await _loadChatHistory();
                                setState(() {
                                  if (_activeChat != null) {
                                    try {
                                      final newActiveChat = _chatHistory
                                          .firstWhere(
                                            (c) => c.id == _activeChat!.id,
                                          );
                                      _activeChat = newActiveChat;
                                    } catch (e) {
                                      _activeChat = null;
                                    }
                                  }
                                });
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The side navigation bar.
          MouseRegion(
            onEnter: (_) => _handleHover(true),
            onExit: (_) => _handleHover(false),
            child: SideNav(
              selectedChat: _activeChat,
              onNewChat: _startNewChat,
              isExpanded: isEffectivelyExpanded,
              isPinned: _isPinned,
              onToggle: _toggleSidebar,
              chatList: _chatHistory,
              onChatSelected: _selectChat,
              onDeleteChat: _deleteChat,
              onArchiveChat: _archiveChat,
              onRenameChat: _renameChat,
              onExportChat: _exportChat,
            ),
          ),
        ],
      ),
    );
  }
}
