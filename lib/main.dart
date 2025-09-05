import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'theme/manager.dart';
import 'ui/main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const Arcadia(),
    ),
  );
}

// --- DATA MODELS ---

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> attachments;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.attachments = const [],
  });
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  bool isNew; // To track if it should be saved

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    this.isNew = true,
  });

  // A method to create a summary for the title
  void generateTitleFromFirstMessage() {
    if (messages.length > 1 && messages[1].isUser) {
      String text = messages[1].text;
      title = text.split(' ').take(5).join(' ');
      if (text.length > title.length) {
        title += '...';
      }
    }
  }
}

// --- MAIN APP ---

class Arcadia extends StatelessWidget {
  const Arcadia({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final themeData = themeManager.getTheme(
              Brightness.light,
              scheme: lightDynamic,
            );
            final darkThemeData = themeManager.getTheme(
              Brightness.dark,
              scheme: darkDynamic,
            );

            return MaterialApp(
              title: 'Arcadia',
              theme: themeData.copyWith(
                textTheme: themeData.textTheme.apply(fontFamily: 'GoogleSans'),
              ),
              darkTheme: darkThemeData.copyWith(
                textTheme: darkThemeData.textTheme.apply(
                  fontFamily: 'GoogleSans',
                ),
              ),
              themeMode: themeManager.themeMode,
              home: const MainUI(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}