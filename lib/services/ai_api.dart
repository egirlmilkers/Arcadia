import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:arcadia/services/api/vertex.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'logging.dart';

/// Handles the content generation in a separate isolate to avoid blocking the UI.
///
/// This function is responsible for making the API call to the service,
/// handling request cancellation, and processing attachments. It communicates
/// back to the main isolate via a `SendPort`.
void _generateContentIsolate(Map<String, dynamic> params) async {
  // Establishes communication channels between the main isolate and this isolate.
  final mainSendPort = params['sendPort'] as SendPort;
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  // Extracts parameters required for the API call.
  final String apiKey = params['apiKey'];
  final String modelUrl = params['url'];
  final List<ChatMessage> messages = (params['messages'] as List)
      .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
      .toList();
  final bool canThink = params['thinking'];
  final String src = params['src'];
  final bool stream = params['stream'];

  final client = http.Client();
  var requestCancelled = false;

  // Listens for a 'cancel' message from the main isolate.
  receivePort.listen((message) {
    if (message == 'cancel') {
      requestCancelled = true;
      client.close();
      receivePort.close();
      ArcadiaLog().info('Content generation cancelled by user.');
    }
  });

  try {
    // Constructs the API endpoint URL.
    final url = Uri.parse('$modelUrl${stream ? ':streamGenerateContent' : ':generateContent'}');

    // Prepares the chat history for the API request.
    var history = List.of(messages);
    final firstUserIndex = history.indexWhere((m) => m.isUser);
    if (firstUserIndex == -1) {
      mainSendPort.send("Error: Cannot send a message without user input.");
      ArcadiaLog().warning('Attempted to send a message without user input.');
      return;
    }
    history = history.sublist(firstUserIndex);

    final Map<String, dynamic> body;
    // Constructs the request body with message content and attachments.
    body = <String, dynamic>{
      'contents': await Future.wait(
        history.map((message) async {
          final parts = <Map<String, dynamic>>[];
          parts.add({'text': message.text});

          // Processes and encodes attachments as base64 strings.
          if (message.attachments.isNotEmpty) {
            for (final attachmentPath in message.attachments) {
              try {
                final file = File(attachmentPath);
                final mimeType = lookupMimeType(attachmentPath);
                if (mimeType != null) {
                  final bytes = await file.readAsBytes();
                  final base64String = base64Encode(bytes);
                  parts.add({
                    'inlineData': {'mimeType': mimeType, 'data': base64String},
                  });
                }
              } catch (e) {
                // Logs an error if an attachment cannot be processed.
                ArcadiaLog().error('Error processing attachment: $attachmentPath', e);
              }
            }
          }

          return {'role': message.isUser ? 'user' : 'model', 'parts': parts};
        }),
      ),
      // prepare safety settings
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_CIVIC_INTEGRITY', 'threshold': 'BLOCK_NONE'},
      ],

      // thinking config
      if (canThink)
        'generationConfig': {
          'thinkingConfig': {'thinkingBudget': -1, 'includeThoughts': true},
        },
    };

    ArcadiaLog().info(body.toString());

    // // Sends the API request.
    final response = await client.post(
      url,
      headers: {
        if (src == 'gemini') 'X-goog-api-key': apiKey,
        if (src != 'gemini') 'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    // Processes the API response.
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final candidates = jsonResponse['candidates'];
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
          final List<dynamic> parts = content['parts'];
          String thoughtSummary = '';
          String finalAnswer = '';

          // Separates the thinking process from the final answer.
          for (final part in parts) {
            if (part['thought'] == true) {
              thoughtSummary += part['text'];
            } else {
              finalAnswer += part['text'];
            }
          }

          // Sends the successful response back to the main isolate.
          mainSendPort.send({'text': finalAnswer, 'thinkingProcess': thoughtSummary});
        } else {
          mainSendPort.send('Error: Invalid response structure from API.');
          ArcadiaLog().error('Invalid response structure: "parts" field is missing or empty.');
        }
      } else {
        mainSendPort.send('Error: Invalid response structure from API.');
        ArcadiaLog().error('Invalid response structure: "candidates" field is missing or empty.');
      }
    } else {
      // Sends an error message if the API call was unsuccessful.
      mainSendPort.send('Error: ${response.statusCode} - \n${response.body}');
      ArcadiaLog().error('API error: ${response.statusCode} - \n${response.body}');
    }
  } catch (e) {
    // Handles any other exceptions that may occur.
    if (requestCancelled) {
      mainSendPort.send(AiApi.cancelledResponse);
    } else {
      mainSendPort.send('Error making API call: $e');
      ArcadiaLog().error('Error in _generateContentIsolate', e, StackTrace.current);
    }
  } finally {
    // Cleans up resources.
    client.close();
    receivePort.close();
  }
}

/// A service for interacting with the API.
///
/// This service manages content generation in a separate isolate to prevent
/// blocking the main UI thread. It provides methods to generate content and

class AiApi {
  /// The API key for accessing the service.
  final String apiKey;

  /// The port for sending messages to the isolate.
  SendPort? _sendPort;

  /// The isolate responsible for content generation.
  Isolate? _isolate;

  /// A constant representing a cancelled response.
  static const String cancelledResponse = 'GEMINI_RESPONSE_CANCELLED';

  /// Creates a new instance of the [AiApi].
  ///
  /// Requires an [apiKey] for authenticating with the API.
  AiApi({required this.apiKey});

  /// Generates content based on a list of messages.
  ///
  /// This method spawns an isolate to handle the API request, ensuring the UI
  /// remains responsive. It returns a `Future` that completes with the
  /// response from the API.
  ///
  /// - [messages]: The list of [ChatMessage]s to send to the model.
  /// - [url]: The URL of the model to use for content generation.
  /// - [thinking]: Whether the model can use the thinking feature.
  Future<Map<String, dynamic>> generateContent(
    List<ChatMessage> messages,
    String url,
    String src, [
    bool? thinking = false,
    bool? stream = false,
  ]) async {
    final completer = Completer<Map<String, dynamic>>();
    final receivePort = ReceivePort();

    final messagesAsJson = messages.map((m) => m.toJson()).toList();

    // Spawns the isolate for content generation.
    _isolate = await Isolate.spawn(_generateContentIsolate, {
      'logger': ArcadiaLog(),
      'sendPort': receivePort.sendPort,
      'apiKey': apiKey,
      'url': url,
      'messages': messagesAsJson,
      'thinking': thinking,
      'src': src,
      'stream': stream,
    });

    // Listens for data from the isolate.
    receivePort.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
      } else if (data is String && data.startsWith('Error:')) {
        // Handles error messages from the isolate.
        completer.complete({'error': data});
        ArcadiaLog().error('Content generation error: $data');
        _cleanup();
      } else if (data is String && data == cancelledResponse) {
        // Handles cancellation.
        completer.complete({'text': cancelledResponse});
        ArcadiaLog().info('Content generation was cancelled.');
        _cleanup();
      } else if (data is Map) {
        // Handles successful responses.
        completer.complete(Map<String, dynamic>.from(data));
        ArcadiaLog().info('Content generated successfully.');
        _cleanup();
      }
    });

    return completer.future;
  }

  /// Cancels the ongoing content generation.
  ///
  /// This method sends a 'cancel' message to the isolate, which will terminate
  /// the API request and clean up resources.
  void cancel() {
    if (_isolate != null) {
      _sendPort?.send('cancel');
      _cleanup();
      ArcadiaLog().info('Cancellation request sent to isolate.');
    }
  }

  /// Cleans up the isolate and its communication ports.
  void _cleanup() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }
}

// A minimal, private helper class just for this function to work.
class ApiKey {
  final String name, key;
  ApiKey({required this.name, required this.key});
  factory ApiKey.fromJson(Map<String, dynamic> json) =>
      ApiKey(name: json['name'] as String, key: json['key'] as String);
}

/// Retrieves a single API key by its name from storage.
Future<String?> getApiKey(String keyName) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('api_keys');
  if (jsonString == null) return null;

  try {
    // get key from api list in settings
    String key = (jsonDecode(jsonString) as List)
        .cast<Map<String, dynamic>>()
        .map(ApiKey.fromJson)
        .firstWhere(
          (k) => k.name.toLowerCase() == keyName.toLowerCase(),
          orElse: () => ApiKey(name: '', key: ''),
        )
        .key;

    // process api key with vertex's complicated ass system
    if (keyName == 'vertex') {
      key = (await VertexAPI.getVertexAIAuth(key))['authHeader'];
      if (key.startsWith('Bearer ')) {
        key = key.split(' ')[1];
      }
    }

    return key.isNotEmpty ? key : null;
  } catch (e) {
    return null;
  }
}
