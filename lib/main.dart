import 'dart:io';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:toastification/toastification.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/model.dart';
import 'services/logging.dart';
import 'theme/manager.dart';
import 'ui/main.dart';
import 'util.dart';

String? appVersion;

void main() async {
  // GoogleFonts.config.allowRuntimeFetching = false;
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Logging.configure();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final packageInfo = await PackageInfo.fromPlatform();
  appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

  if (Platform.isWindows) {
    // fixes clipboard history flutter bug
    WindowsInjector.instance.injectKeyData();

    WindowManager.instance.setMinimumSize(const Size(640, 480));
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
// - refresh data
// - chat popup menu doesnt work if  not pinned
// - generate even if switching tabs

// ===== Future Updates =====
// - gemma
// - android version
// - allow models like chatgpt and deepseek
// - pinning chats
// - drag and drop files
// - view archived chats
// - personalized starter prompt
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

  /// The thinking process summary from the AI.
  String? thinkingProcess;

  /// A list of file paths for any attachments.
  final List<String> attachments;

  /// The timestamp of when the message was created.
  final DateTime createdAt;


  ChatMessage({
    required this.text,
    required this.isUser,
    this.thinkingProcess,
    this.attachments = const [],
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
      thinkingProcess: json['thinkingProcess'],
      attachments: List<String>.from(json['attachments']),
      createdAt: DateTime.parse(json['createdAt']),
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
class ArcadiaChat {
  /// A unique identifier for the chat session.
  final String id;

  /// The title of the chat session.
  String title;

  /// The list of messages in the chat session.
  final List<ChatMessage> messages;

  /// The version of the app that this chat was created in.
  final String version;

  ArcadiaChat({
    String? id,
    required this.title,
    required this.messages,
    required this.version,
  }) : id = id ?? const Uuid().v4();

  /// Creates a [ArcadiaChat] from a JSON object.
  factory ArcadiaChat.fromJson(Map<String, dynamic> json) {
    return ArcadiaChat(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((message) => ChatMessage.fromJson(message))
          .toList(),
      version: json['version'] ?? '1.0.0+1',
    );
  }

  /// Converts the [ArcadiaChat] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((message) => message.toJson()).toList(),
      'version': version,
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

    return ToastificationWrapper(
      child: Consumer<ThemeManager>(
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
                  textTheme: themeData.textTheme.apply(
                    fontFamily: 'GoogleSans',
                  ),
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
      ),
    );
  }
}
