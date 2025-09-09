import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:mime/mime.dart';

import '../main.dart';

void _generateContentIsolate(Map<String, dynamic> params) async {
  final mainSendPort = params['sendPort'] as SendPort;
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  final String apiKey = params['apiKey'];
  final String model = params['model'];
  final List<ChatMessage> messages = (params['messages'] as List)
      .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
      .toList();

  const String host = 'generativelanguage.googleapis.com';

  HttpClient? client = HttpClient();
  var requestCancelled = false;

  receivePort.listen((message) {
    if (message == 'cancel') {
      requestCancelled = true;
      client?.close(force: true);
      client = null;
      receivePort.close();
    }
  });

  try {
    InternetAddress? ipAddress;
    try {
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      );
      if (addresses.isNotEmpty) {
        ipAddress = addresses.first;
      } else {
        mainSendPort.send('Error: Could not resolve DNS for API host (IPv4).');
        return;
      }
    } on SocketException catch (e) {
      mainSendPort.send(
        'Error: DNS lookup failed. Code: ${e.osError?.errorCode}, Message: ${e.osError?.message}',
      );
      return;
    }

    if (requestCancelled) {
      mainSendPort.send(GeminiService.cancelledResponse);
      return;
    }

    final url = Uri.parse(
      'https://${ipAddress.address}/v1beta/models/$model:generateContent',
    );

    var history = List.of(messages);
    final firstUserIndex = history.indexWhere((m) => m.isUser);
    if (firstUserIndex == -1) {
      mainSendPort.send("Error: Cannot send a message without user input.");
      return;
    }
    history = history.sublist(firstUserIndex);

    final body = {
      'contents': await Future.wait(
        history.map((message) async {
          final parts = <Map<String, dynamic>>[];
          parts.add({'text': message.text});

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
                // Can't really do anything here, just print and continue
                print('Error processing attachment: $e');
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

    client!.badCertificateCallback =
        (X509Certificate cert, String connectedHost, int port) {
          return cert.subject.contains('CN=*.googleapis.com');
        };

    final request = await client!.postUrl(url);

    request.headers.set('Host', host);
    request.headers.set('x-goog-api-key', apiKey);
    request.headers.set('Content-Type', 'application/json; charset=UTF-8');

    request.write(jsonEncode(body));

    final response = await request.close();

    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(responseBody);
      if (jsonResponse['candidates'] != null &&
          jsonResponse['candidates'].isNotEmpty &&
          jsonResponse['candidates'][0]['content'] != null &&
          jsonResponse['candidates'][0]['content']['parts'] != null &&
          jsonResponse['candidates'][0]['content']['parts'].isNotEmpty) {
        
        final List<dynamic> parts = jsonResponse['candidates'][0]['content']['parts'];
        String thoughtSummary = '';
        String finalAnswer = '';

        for (final part in parts) {
          // The documentation uses a 'thought' boolean field to distinguish parts.
          if (part['thought'] == true) {
            thoughtSummary += part['text'];
          } else {
            finalAnswer += part['text'];
          }
        }

        mainSendPort.send({
          'text': finalAnswer,
          'thinkingProcess': thoughtSummary,
        });
      } else {
        mainSendPort.send('Error: Invalid response structure from API.');
      }
    } else {
      mainSendPort.send('Error: ${response.statusCode} - $responseBody');
    }
  } catch (e) {
    if (requestCancelled) {
      mainSendPort.send(GeminiService.cancelledResponse);
    } else {
      mainSendPort.send('Error making API call: $e');
    }
  } finally {
    client?.close();
    receivePort.close();
  }
}

class GeminiService {
  final String apiKey;
  SendPort? _sendPort;
  Isolate? _isolate;

  static const String cancelledResponse = 'GEMINI_RESPONSE_CANCELLED';

  GeminiService({required this.apiKey});

  Future<Map<String, dynamic>> generateContent(
    List<ChatMessage> messages,
    String model,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final receivePort = ReceivePort();

    final messagesAsJson = messages.map((m) => m.toJson()).toList();

    _isolate = await Isolate.spawn(_generateContentIsolate, {
      'sendPort': receivePort.sendPort,
      'apiKey': apiKey,
      'model': model,
      'messages': messagesAsJson,
    });

    receivePort.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
      } else if (data is String) {
        // Handle error case
        completer.complete({'error': data});
        receivePort.close();
        _isolate?.kill();
        _isolate = null;
        _sendPort = null;
      } else if (data is Map) {
        completer.complete(Map<String, dynamic>.from(data));
        receivePort.close();
        _isolate?.kill();
        _isolate = null;
        _sendPort = null;
      }
    });

    return completer.future;
  }

  void cancel() {
    if (_isolate != null) {
      _sendPort?.send('cancel');
      _isolate = null;
      _sendPort = null;
    }
  }
}
