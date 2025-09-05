import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../main.dart';

class ChatHistoryService {
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/chat_history.json');
  }

  Future<List<ChatSession>> loadChats() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> json = jsonDecode(contents);
      return json.map((chat) => ChatSession.fromJson(chat)).toList();
    } catch (e) {
      print('Error loading chats: $e');
      return [];
    }
  }

  Future<void> saveChats(List<ChatSession> chats) async {
    try {
      final file = await _localFile;
      final List<dynamic> json = chats.map((chat) => chat.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      print('Error saving chats: $e');
    }
  }

  Future<void> addChat(ChatSession chat) async {
    final chats = await loadChats();
    chats.add(chat);
    await saveChats(chats);
  }
}
