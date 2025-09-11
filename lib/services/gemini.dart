import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:mime/mime.dart';

import '../main.dart';
import 'logging.dart';

/// Handles the content generation in a separate isolate to avoid blocking the UI.
///
/// This function is responsible for making the API call to the Gemini service,
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

  // The host for the Gemini API.
  final host = Uri.parse(modelUrl).host;

  HttpClient? client = HttpClient();
  var requestCancelled = false;
  final logger = Logging();

  // Listens for a 'cancel' message from the main isolate.
  receivePort.listen((message) {
    if (message == 'cancel') {
      requestCancelled = true;
      client?.close(force: true);
      client = null;
      receivePort.close();
      logger.info('Content generation cancelled by user.');
    }
  });

  try {
    try {
      // Performs a DNS lookup to get the IP address of the API host.
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      );
      if (!addresses.isNotEmpty) {
        // Sends an error message if DNS resolution fails.
        mainSendPort.send('Error: Could not resolve DNS for API host (IPv4).');
        logger.error('Could not resolve DNS for API host (IPv4).');
        return;
      }
    } on SocketException catch (e) {
      // Handles exceptions during DNS lookup.
      mainSendPort.send(
        'Error: DNS lookup failed. Code: ${e.osError?.errorCode}, Message: ${e.osError?.message}',
      );
      logger.error('DNS lookup failed', e, StackTrace.current);
      return;
    }

    // Checks if the request was cancelled before proceeding.
    if (requestCancelled) {
      mainSendPort.send(GeminiService.cancelledResponse);
      return;
    }

    // Constructs the API endpoint URL.
    final url = Uri.parse(modelUrl);

    // Prepares the chat history for the API request.
    var history = List.of(messages);
    final firstUserIndex = history.indexWhere((m) => m.isUser);
    if (firstUserIndex == -1) {
      mainSendPort.send("Error: Cannot send a message without user input.");
      logger.warning('Attempted to send a message without user input.');
      return;
    }
    history = history.sublist(firstUserIndex);

    // Constructs the request body with message content and attachments.
    final body = {
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
                logger.error('Error processing attachment: $attachmentPath', e);
              }
            }
          }

          return {'role': message.isUser ? 'user' : 'model', 'parts': parts};
        }),
      ),
      "generationConfig": {
        "thinkingConfig": {"thinkingBudget": -1, "includeThoughts": true},
      },
    };

    // Configures the HttpClient to trust the Google API certificate.
    client!.badCertificateCallback =
        (X509Certificate cert, String connectedHost, int port) {
          return cert.subject.contains(host);
        };

    // Sends the API request.
    final request = await client!.postUrl(url);
    request.headers.set('Host', host);
    request.headers.set('x-goog-api-key', apiKey);
    request.headers.set('Content-Type', 'application/json; charset=UTF-8');
    request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    // Processes the API response.
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(responseBody);
      final candidates = jsonResponse['candidates'];
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null &&
            content['parts'] != null &&
            content['parts'].isNotEmpty) {
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
          mainSendPort.send({
            'text': finalAnswer,
            'thinkingProcess': thoughtSummary,
          });
        } else {
          mainSendPort.send('Error: Invalid response structure from API.');
          logger.error(
            'Invalid response structure: "parts" field is missing or empty.',
          );
        }
      } else {
        mainSendPort.send('Error: Invalid response structure from API.');
        logger.error(
          'Invalid response structure: "candidates" field is missing or empty.',
        );
      }
    } else {
      // Sends an error message if the API call was unsuccessful.
      mainSendPort.send('Error: ${response.statusCode} - $responseBody');
      logger.error('API error: ${response.statusCode} - $responseBody');
    }
  } catch (e) {
    // Handles any other exceptions that may occur.
    if (requestCancelled) {
      mainSendPort.send(GeminiService.cancelledResponse);
    } else {
      mainSendPort.send('Error making API call: $e');
      logger.error('Error in _generateContentIsolate', e, StackTrace.current);
    }
  } finally {
    // Cleans up resources.
    client?.close();
    receivePort.close();
  }
}

/// A service for interacting with the Gemini API.
///
/// This service manages content generation in a separate isolate to prevent
/// blocking the main UI thread. It provides methods to generate content and

class GeminiService {
  /// The API key for accessing the Gemini service.
  final String apiKey;

  /// The port for sending messages to the isolate.
  SendPort? _sendPort;

  /// The isolate responsible for content generation.
  Isolate? _isolate;

  /// A constant representing a cancelled response.
  static const String cancelledResponse = 'GEMINI_RESPONSE_CANCELLED';

  /// Creates a new instance of the [GeminiService].
  ///
  /// Requires an [apiKey] for authenticating with the Gemini API.
  GeminiService({required this.apiKey});

  /// Generates content based on a list of messages.
  ///
  /// This method spawns an isolate to handle the API request, ensuring the UI
  /// remains responsive. It returns a `Future` that completes with the
  /// response from the API.
  ///
  /// - [messages]: The list of [ChatMessage]s to send to the model.
  /// - [url]: The URL of the model to use for content generation.
  Future<Map<String, dynamic>> generateContent(
    List<ChatMessage> messages,
    String url,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final receivePort = ReceivePort();
    final logger = Logging();

    final messagesAsJson = messages.map((m) => m.toJson()).toList();

    // Spawns the isolate for content generation.
    _isolate = await Isolate.spawn(_generateContentIsolate, {
      'sendPort': receivePort.sendPort,
      'apiKey': apiKey,
      'url': url,
      'messages': messagesAsJson,
    });

    // Listens for data from the isolate.
    receivePort.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
      } else if (data is String && data.startsWith('Error:')) {
        // Handles error messages from the isolate.
        completer.complete({'error': data});
        logger.error('Content generation error: $data');
        _cleanup();
      } else if (data is String && data == cancelledResponse) {
        // Handles cancellation.
        completer.complete({'text': cancelledResponse});
        logger.info('Content generation was cancelled.');
        _cleanup();
      } else if (data is Map) {
        // Handles successful responses.
        completer.complete(Map<String, dynamic>.from(data));
        logger.info('Content generated successfully.');
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
      Logging().info('Cancellation request sent to isolate.');
    }
  }

  /// Cleans up the isolate and its communication ports.
  void _cleanup() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }
}
