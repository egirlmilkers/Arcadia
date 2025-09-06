import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

  void _loadChatHistory() async {
    _chatHistory = await _chatHistoryService.loadChats();
    setState(() {});
  }

  void _startNewChat() {
    setState(() {
      _activeChat = ChatSession(
        id: Uuid().v4(),
        title: 'New Chat',
        messages: [],
        isNew: true,
      );
    });
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
                    PopupMenuButton<String>(
                      tooltip: "Choose your model",
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      onSelected: (String modelName) {
                        modelManager.setSelectedModel(modelName);
                      },
                      itemBuilder: (BuildContext context) {
                        return modelManager.models.map((Model model) {
                          return PopupMenuItem<String>(
                            value: model.modelName,
                            child: ListTile(
                              title: Text(model.displayName),
                              subtitle: Text(model.subtitle),
                            ),
                          );
                        }).toList();
                      },
                      child: Card(
                        color: theme.colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Text(modelManager.selectedModel.displayName),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
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
                              onNewMessage: (String title) {
                                _loadChatHistory();
                                setState(() {
                                  _activeChat!.title = title;
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
              onNewChat: _startNewChat,
              isExpanded: isEffectivelyExpanded,
              isPinned: _isPinned,
              onToggle: _toggleSidebar,
              chatHistory: _chatHistory,
              onChatSelected: _selectChat,
            ),
          ),
        ],
      ),
    );
  }
}
