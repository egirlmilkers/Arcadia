import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../main.dart';

class ChatHistoryService {
  Future<Directory> _getChatsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final chatsDir = Directory(p.join(docs.path, 'Arcadia', 'chats'));
    if (!await chatsDir.exists()) {
      await chatsDir.create(recursive: true);
    }
    return chatsDir;
  }

  Future<List<ChatSession>> loadChats() async {
    try {
      final chatsDir = await _getChatsDirectory();
      final chatFiles = chatsDir.listSync().where(
        (f) => f.path.endsWith('.json'),
      );

      final chats = <ChatSession>[];
      for (final file in chatFiles) {
        try {
          final content = await (file as File).readAsString();
          final json = jsonDecode(content);
          chats.add(ChatSession.fromJson(json));
        } catch (e) {
          print('Error loading chat file: ${file.path}, $e');
        }
      }
      chats.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      return chats;
    } catch (e) {
      print('Error loading chats: $e');
      return [];
    }
  }

  Future<void> saveChat(ChatSession chat) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final file = File(p.join(chatsDir.path, '${chat.id}.json'));
      await file.writeAsString(jsonEncode(chat.toJson()));
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  Future<void> deleteChat(ChatSession chat) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final file = File(p.join(chatsDir.path, '${chat.id}.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting chat: $e');
    }
  }

  Future<void> renameChat(ChatSession chat, String newTitle) async {
    chat.title = newTitle;
    await saveChat(chat);
  }

  Future<void> archiveChat(ChatSession chat) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final archiveDir = Directory(p.join(chatsDir.path, 'archived'));
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }

      final file = File(p.join(chatsDir.path, '${chat.id}.json'));
      if (await file.exists()) {
        await file.rename(p.join(archiveDir.path, '${chat.id}.json'));
      }
    } catch (e) {
      print('Error archiving chat: $e');
    }
  }

  Future<void> addChat(ChatSession chat) async {
    await saveChat(chat);
  }
}
