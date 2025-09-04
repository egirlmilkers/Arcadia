import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'theme/manager.dart';
import 'ui/settings.dart';

// --- THEME MANAGEMENT ---
// Your new theme manager will be provided to the app.

void main() {
  // Ensure that plugin services are initialized so that `shared_preferences` can be used.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const GeminiApp(),
    ),
  );
}

// A simple data class for a chat message.
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class GeminiApp extends StatelessWidget {
  const GeminiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        // Use a DynamicColorBuilder to get system accent colors
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return MaterialApp(
              title: 'Arcadia',
              // Get themes from your manager
              theme: themeManager.getTheme(
                Brightness.light,
                scheme: lightDynamic,
              ),
              darkTheme: themeManager.getTheme(
                Brightness.dark,
                scheme: darkDynamic,
              ),
              themeMode: themeManager.themeMode,
              home: const MainScreen(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

// --- MAIN LAYOUT ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // We'll use a nullable ChatMessage list to represent the active chat.
  // If it's null, we show the WelcomeView. If it's a list, we show the ChatScreen.
  List<ChatMessage>? _activeChat;

  void _startNewChat() {
    setState(() {
      _activeChat = [
        ChatMessage(text: "Hi there! How can I help you today?", isUser: false),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // The persistent sidebar
          SideMenu(onNewChat: _startNewChat),
          // The main content area
          Expanded(
            child: _activeChat == null
                ? const WelcomeView()
                : ChatScreen(messages: _activeChat!),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class SideMenu extends StatelessWidget {
  final VoidCallback onNewChat;
  const SideMenu({super.key, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      color: theme.colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Title/Logo
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
            child: Text(
              "Gemini",
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          // New Chat Button
          ElevatedButton.icon(
            onPressed: onNewChat,
            icon: const Icon(Icons.add),
            label: const Text("New Chat"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Chat History Section
          Text("Recent", style: theme.textTheme.titleSmall),
          Expanded(
            child: ListView(
              children: [
                // Mock chat history items
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text("Recipe for a great weekend..."),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text("Flutter state management explained"),
                  onTap: () {},
                ),
              ],
            ),
          ),
          // Settings and Theme Toggle
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Settings"),
            onTap: () {
              // Navigate to the new settings page
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient Text
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFF9B72CB),
                  Color(0xFFD96570),
                  Color(0xFFF2A600),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                "Hello, there",
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // This color is necessary for ShaderMask
                ),
              ),
            ),
            Text(
              "How can I help you today?",
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            // Suggestion Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SuggestionCard(icon: Icons.code, text: "Help me code"),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SuggestionCard(
                    icon: Icons.edit,
                    text: "Help me write",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SuggestionCard(
                    icon: Icons.lightbulb_outline,
                    text: "Give me ideas",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SuggestionCard(
                    icon: Icons.flight_takeoff,
                    text: "Help me plan",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const SuggestionCard({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  const ChatScreen({super.key, required this.messages});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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

      // --- TODO: API call goes here ---
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
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final message = widget.messages[index];
              return MessageBubble(message: message);
            },
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
            Expanded(
              child: TextField(
                controller: _textController,
                onSubmitted: (_) => _sendMessage(),
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
                maxLines: null,
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

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18.0).copyWith(
            bottomRight: isUser ? const Radius.circular(4.0) : null,
            bottomLeft: !isUser ? const Radius.circular(4.0) : null,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gemini',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            if (!isUser) const SizedBox(height: 8),
            SelectableText(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
