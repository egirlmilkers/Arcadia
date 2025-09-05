import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../main.dart';
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
  List<ChatMessage>? _activeChat;
  bool _isPinned = true;
  bool _isHovering = false;

  void _startNewChat() {
    setState(() {
      _activeChat = [
        ChatMessage(
          text: "Hi there! How can I help you today?",
          isUser: false,
        ),
      ];
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
    final theme = Theme.of(context);
    final gradientColors = themeManager.currentTheme?.gradientColors ??
        [theme.colorScheme.primary, theme.colorScheme.tertiary];
    final bool isEffectivelyExpanded = _isPinned || _isHovering;

    return Scaffold(
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => _handleHover(true),
            onExit: (_) => _handleHover(false),
            child: SideNav(
              onNewChat: _startNewChat,
              isExpanded: isEffectivelyExpanded,
              onToggle: _toggleSidebar,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, left: 24.0),
                  child: GestureDetector(
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
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: 200.ms,
                    margin: EdgeInsets.only(left: _isPinned ? 0 : 20),
                    child: _activeChat == null
                        ? const WelcomeUI()
                        : ChatUI(messages: _activeChat!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}