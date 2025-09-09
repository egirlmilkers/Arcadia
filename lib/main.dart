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
  // GoogleFonts.config.allowRuntimeFetching = false;

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

// ========== TODO ==========
// - thinking dropdown
// - scroll issue with codeblock
// - chats sometimes not loading

// - problems (print)
// - comments and spacing
// - github autobuild
// - web version
// - raem theme

// ===== Future Updates =====
// - gemma
// - android version
// - allow models like chatgpt and deepseek
// - app icon
// - pinning chats
// - drag and drop files
// - view archived chats
// - logs with every ui element interaction logged
// - personalized starter prompt
// - streaming output & thinking
// - action buttons scroll with app bar
// - selectable syntax themes
// - table format
// - thought for x seconds
// - split widgets
// - warning popups with (dont ask again) remembering

class ChatMessage {
  final String id;
  String text;
  final bool isUser;
  final List<String> attachments;
  final DateTime createdAt;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.attachments = const [],
    String? id,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      attachments: List<String>.from(json['attachments']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;

  ChatSession({String? id, required this.title, required this.messages})
    : id = id ?? Uuid().v4();

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((message) => ChatMessage.fromJson(message))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  DateTime get lastModified {
    if (messages.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return messages.last.createdAt;
  }
}

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
