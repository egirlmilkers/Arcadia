import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/chat_history.dart';
import '../services/model.dart';
import '../theme/manager.dart';
import 'chat.dart';
import 'nav.dart';
import 'welcome.dart';

class MainUI extends StatefulWidget {
  const MainUI({super.key});

  @override
  State<MainUI> createState() => _MainUIState();
}

class _MainUIState extends State<MainUI> {
  ChatSession? _activeChat;
  List<ChatSession> _chatHistory = [];
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  bool _isPinned = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _loadPinState();
    _startNewChat();
  }

  void _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPinned = prefs.getBool('isPinned') ?? true;
    });
  }

  void _savePinState(bool isPinned) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isPinned', isPinned);
  }

  Future<void> _loadChatHistory() async {
    _chatHistory = await _chatHistoryService.loadChats();
  }

  void _startNewChat() {
    setState(() {
      _activeChat = ChatSession(title: 'New Chat', messages: []);
    });
  }

  void _deleteChat(ChatSession chat) async {
    // If the active chat is the one being deleted, set it to null.
    if (_activeChat?.id == chat.id) {
      _activeChat = null;
    }
    await _chatHistoryService.deleteChat(chat);
    await _loadChatHistory();
    setState(() {}); // Rebuild the UI with the updated list and active chat.
  }

  void _archiveChat(ChatSession chat) async {
    // Archiving should also clear the active chat view.
    if (_activeChat?.id == chat.id) {
      _activeChat = null;
    }
    await _chatHistoryService.archiveChat(chat);
    await _loadChatHistory();
    setState(() {});
  }

  void _renameChat(ChatSession chat, String newTitle) async {
    final activeChatId = _activeChat?.id;
    await _chatHistoryService.renameChat(chat, newTitle);
    await _loadChatHistory();

    // If the renamed chat was the active one, find its new instance in the
    // updated list and set it as the active chat. This ensures the title
    // updates everywhere.
    if (activeChatId == chat.id) {
      try {
        _activeChat = _chatHistory.firstWhere((c) => c.id == activeChatId);
      } catch (e) {
        // In case the chat was deleted by another process, handle it gracefully.
        _activeChat = null;
      }
    }
    setState(() {});
  }

  void _selectChat(ChatSession chat) {
    setState(() {
      _activeChat = chat;
    });
  }

  void _resetToHome() {
    setState(() {
      _activeChat = null;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isPinned = !_isPinned;
      _savePinState(_isPinned);
    });
  }

  void _handleHover(bool hover) {
    // We only want to expand on hover if the sidebar is not pinned open
    if (!_isPinned) {
      setState(() {
        _isHovering = hover;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    final modelManager = context.watch<ModelManager>();
    final theme = Theme.of(context);

    // Add this check at the top of the build method.
    if (modelManager.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final gradientColors =
        themeManager.currentTheme?.gradientColors ??
        [theme.colorScheme.primary, theme.colorScheme.tertiary];
    final bool isEffectivelyExpanded = _isPinned || _isHovering;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedPadding(
            duration: 200.ms,
            padding: EdgeInsets.only(left: _isPinned ? 280 : 74),
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (!modelManager.loading)
                    Center(
                      child: Tooltip(
                        message: "Choose your model",
                        child: Builder(
                          // A Builder is used here to get a specific context for the button,
                          // which is needed to calculate its position on the screen for `showMenu`.
                          builder: (BuildContext context) {
                            return Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip
                                  .antiAlias, // Ensures the InkWell ripple is clipped
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  // THIS IS THE SIMPLIFIED PART
                                  final RenderBox button =
                                      context.findRenderObject() as RenderBox;
                                  final RenderBox overlay =
                                      Overlay.of(
                                            context,
                                          ).context.findRenderObject()
                                          as RenderBox;

                                  // 1. Get the button's position and size in the overlay's coordinate system.
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

                                  // 2. offset the menu to show next to the dropdown button
                                  final Rect shiftedButtonRect = buttonRect
                                      .translate(-110.0, 0.0);

                                  // 3. Create the RelativeRect for the menu's position.
                                  final RelativeRect position =
                                      RelativeRect.fromRect(
                                        shiftedButtonRect,
                                        Offset.zero & overlay.size,
                                      );

                                  // Show the menu anchored to the button's calculated position.
                                  showMenu<String>(
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
                                      return PopupMenuItem<String>(
                                        value: model.modelName,
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
                                  ).then((String? value) {
                                    // This is the equivalent of `onSelected`.
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
                                    mainAxisSize: MainAxisSize
                                        .min, // Fit the row to its content
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
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: 500.ms,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: _activeChat == null
                          ? const WelcomeUI()
                          : ChatUI(
                              key: ValueKey(_activeChat!.id),
                              chatSession: _activeChat!,
                              selectedModel:
                                  modelManager.selectedModel.modelName,
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
            ),
          ),
        ],
      ),
    );
  }
}
