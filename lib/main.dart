import 'dart:io';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:uuid/uuid.dart';

import 'services/model.dart';
import 'theme/manager.dart';
import 'ui/main.dart';
import 'util.dart';


void main() {
  if (Platform.isWindows) {
    // fixes clipboard history flutter bug
    WindowsInjector.instance.injectKeyData();
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        ChangeNotifierProvider(create: (_) => ModelManager()),
      ],
      child: const Arcadia(),
    ),
  );
}

// TODO:
// - Attachment display
// - thinking dropdown
// - make markdown work
// - chat list not filling all space
// - chat management
// - loading spinner
// - model highlight should only highlight button
// - fix chat files
// - chat change animation
// - fix api errors from sending in chat
// - only show action buttons for latest and hovered over msg
// - remove sent message and put text back in text box on api fail
// - chat switching error

// --- DATA MODELS ---

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final List<String> attachments;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.attachments = const [],
    String? id,
  }) : id = id ?? Uuid().v4();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      attachments: List<String>.from(json['attachments']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'attachments': attachments,
    };
  }
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

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((message) => ChatMessage.fromJson(message))
          .toList(),
      isNew: json['isNew'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((message) => message.toJson()).toList(),
      'isNew': isNew,
    };
  }

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
