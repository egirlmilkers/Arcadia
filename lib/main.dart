import 'dart:io';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:uuid/uuid.dart';

import 'services/model.dart';
import 'services/logging.dart';
import 'theme/manager.dart';
import 'ui/main.dart';
import 'util.dart';

void main() async {
  // GoogleFonts.config.allowRuntimeFetching = false;
  WidgetsFlutterBinding.ensureInitialized();
  await Logging.configure();

  if (Platform.isWindows) {
    // fixes clipboard history flutter bug
    WindowsInjector.instance.injectKeyData();
  }

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
// - web version
// - resizing the window too small breaks it
// - chat file versions
// - investigate thinking

// ===== Future Updates =====
// - gemma
// - android version
// - allow models like chatgpt and deepseek
// - pinning chats
// - drag and drop files
// - view archived chats
// - personalized starter prompt
// - streaming output & thinking
// - action buttons scroll with app bar
// - selectable syntax themes
// - table format
// - thought for x seconds
// - split widgets to files
// - warning popups with (dont ask again) remembering
// - allow all files attachment

/// Represents a single message in a chat session.
class ChatMessage {
  /// A unique identifier for the message.
  final String id;

  /// The text content of the message.
  String text;

  /// Whether the message was sent by the user.
  final bool isUser;

  /// A list of file paths for any attachments.
  final List<String> attachments;

  /// The timestamp of when the message was created.
  final DateTime createdAt;

  /// The thinking process summary from the AI.
  final String? thinkingProcess;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.attachments = const [],
    this.thinkingProcess,
    String? id,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now();

  /// Creates a [ChatMessage] from a JSON object.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      attachments: List<String>.from(json['attachments']),
      createdAt: DateTime.parse(json['createdAt']),
      thinkingProcess: json['thinkingProcess'],
    );
  }

  /// Converts the [ChatMessage] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'thinkingProcess': thinkingProcess,
    };
  }
}

/// Represents a chat session, which contains a list of messages and a title.
class ChatSession {
  /// A unique identifier for the chat session.
  final String id;

  /// The title of the chat session.
  String title;

  /// The list of messages in the chat session.
  final List<ChatMessage> messages;

  ChatSession({String? id, required this.title, required this.messages})
    : id = id ?? const Uuid().v4();

  /// Creates a [ChatSession] from a JSON object.
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((message) => ChatMessage.fromJson(message))
          .toList(),
    );
  }

  /// Converts the [ChatSession] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  /// Returns the timestamp of the last message in the session.
  DateTime get lastModified {
    if (messages.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return messages.last.createdAt;
  }
}

/// The root widget of the application.
///
/// This widget sets up the theme and initial routing for the app.
class Arcadia extends StatelessWidget {
  const Arcadia({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to listen for changes in the ThemeManager.
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        // Use a DynamicColorBuilder to get the device's dynamic colors.
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            // Get the light and dark themes from the ThemeManager.
            final themeData = themeManager.getTheme(
              Brightness.light,
              scheme: lightDynamic,
            );
            final darkThemeData = themeManager.getTheme(
              Brightness.dark,
              scheme: darkDynamic,
            );

            // The main MaterialApp widget.
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
