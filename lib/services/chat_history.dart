import 'dart:convert';
import 'dart:io';

import 'package:arcadia/util.dart';
import 'package:path/path.dart' as p;

import '../main.dart';
import 'logging.dart';

/// A service for managing chat history, including loading, saving, deleting,
/// and archiving chat sessions.
///
/// This service handles all file system operations related to chat history,
/// ensuring that chat data is persisted across application launches.
class ChatHistoryService {
  /// Returns the directory where chat files are stored.
  ///
  /// If the directory does not exist, it will be created.
  Future<Directory> _getChatsDirectory() async {
    final chatsDir = await getArcadiaDocuments('chats');
    if (!await chatsDir.exists()) {
      await chatsDir.create(recursive: true);
      ArcadiaLog().info('Created chats directory at ${chatsDir.path}');
    }
    return chatsDir;
  }

  /// Loads all chat sessions from the file system.
  ///
  /// This method reads all `.json` files from the chats directory, decodes
  /// them into [ArcadiaChat] objects, and returns them sorted by last
  /// modified date.
  Future<List<ArcadiaChat>> loadChats() async {
    try {
      final chatsDir = await _getChatsDirectory();
      final chatFiles = chatsDir.listSync().where((f) => f.path.endsWith('.json'));

      final chats = <ArcadiaChat>[];
      for (final file in chatFiles) {
        try {
          final content = await (file as File).readAsString();
          final json = jsonDecode(content);
          chats.add(ArcadiaChat.fromJson(json));
        } catch (e, s) {
          ArcadiaLog().error('Error loading chat file: ${file.path}', e, s);
        }
      }
      // Sort chats by last modified date in descending order.
      chats.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      ArcadiaLog().info('Loaded ${chats.length} chats.');
      return chats;
    } catch (e, s) {
      ArcadiaLog().error('Error loading chats', e, s);
      return [];
    }
  }

  /// Saves a chat session to the file system.
  ///
  /// This method serializes the [chat] object to JSON and writes it to a file
  /// named after the chat's ID.
  Future<void> saveChat(ArcadiaChat chat) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final file = File(p.join(chatsDir.path, '${chat.id}.json'));
      await file.writeAsString(jsonEncode(chat.toJson()));
      ArcadiaLog().info('Saved chat with ID: ${chat.id}');
    } catch (e, s) {
      ArcadiaLog().error('Error saving chat with ID: ${chat.id}', e, s);
    }
  }

  /// Deletes a chat session from the file system.
  ///
  /// This method deletes the file corresponding to the given [chat].
  Future<void> deleteChat(ArcadiaChat chat) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final file = File(p.join(chatsDir.path, '${chat.id}.json'));
      if (await file.exists()) {
        await file.delete();
        ArcadiaLog().info('Deleted chat with ID: ${chat.id}');
      }
    } catch (e, s) {
      ArcadiaLog().error('Error deleting chat with ID: ${chat.id}', e, s);
    }
  }

  /// Renames a chat session.
  ///
  /// This method updates the title of the [chat] and saves it.
  Future<void> renameChat(ArcadiaChat chat, String newTitle) async {
    chat.title = newTitle;
    await saveChat(chat);
    ArcadiaLog().info('Renamed chat with ID: ${chat.id} to "$newTitle"');
  }

  /// Archives a chat session.
  ///
  /// This method moves the chat file to an 'archived' subdirectory.
  Future<void> archiveChat(ArcadiaChat chat) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final archiveDir = Directory(p.join(chatsDir.path, 'archived'));
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
        ArcadiaLog().info('Created archive directory at ${archiveDir.path}');
      }

      final file = File(p.join(chatsDir.path, '${chat.id}.json'));
      if (await file.exists()) {
        await file.rename(p.join(archiveDir.path, '${chat.id}.json'));
        ArcadiaLog().info('Archived chat with ID: ${chat.id}');
      }
    } catch (e, s) {
      ArcadiaLog().error('Error archiving chat with ID: ${chat.id}', e, s);
    }
  }

  /// Adds a new chat session.
  ///
  /// This is an alias for [saveChat].
  Future<void> addChat(ArcadiaChat chat) async {
    await saveChat(chat);
  }
}
