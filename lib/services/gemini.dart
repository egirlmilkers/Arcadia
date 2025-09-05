import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
// Note: We are no longer using the 'http' package directly in the isolate.
// import 'package:http/http.dart' as http;

import '../main.dart';

Future<String> _generateContentIsolate(Map<String, dynamic> params) async {
  final String apiKey = params['apiKey'];
  final String model = params['model'];
  final List<ChatMessage> messages = (params['messages'] as List)
      .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
      .toList();

  const String host = 'generativelanguage.googleapis.com';
  
  InternetAddress? ipAddress;
  try {
    final addresses = await InternetAddress.lookup(host, type: InternetAddressType.IPv4);
    if (addresses.isNotEmpty) {
      ipAddress = addresses.first;
    } else {
      return 'Error: Could not resolve DNS for API host (IPv4).';
    }
  } on SocketException catch (e) {
    return 'Error: DNS lookup failed. Code: ${e.osError?.errorCode}, Message: ${e.osError?.message}';
  }

  final url = Uri.parse(
    'https://${ipAddress.address}/v1beta/models/$model:generateContent',
  );

  var history = List.of(messages);
  final firstUserIndex = history.indexWhere((m) => m.isUser);
  if (firstUserIndex == -1) {
    return "Error: Cannot send a message without user input.";
  }
  history = history.sublist(firstUserIndex);

  final body = {
    'contents': history.map((message) {
      return {
        'role': message.isUser ? 'user' : 'model',
        'parts': [
          {'text': message.text},
        ],
      };
    }).toList(),
  };

  HttpClient? client;
  try {
    // Create a low-level HttpClient.
    client = HttpClient();
    
    // This callback is the core of the fix. It's called when the certificate
    // name doesn't match the host we are connecting to (our IP address).
    client.badCertificateCallback = (X509Certificate cert, String connectedHost, int port) {
      // We return 'true' if the certificate's subject Common Name (CN) is for the
      // googleapis.com domain. This tells the client to trust the certificate
      // despite the mismatch, preventing the exception that crashes the VM.
      return cert.subject.contains('CN=*.googleapis.com');
    };

    // Manually open the request to our IP-based URL.
    final request = await client.postUrl(url);

    // Set the necessary headers. The 'Host' header is still essential.
    request.headers.set('Host', host);
    request.headers.set('x-goog-api-key', apiKey);
    request.headers.set('Content-Type', 'application/json; charset=UTF-8');
    
    // Write the body and close the request to send it.
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 60));

    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(responseBody);
      if (jsonResponse['candidates'] != null &&
          jsonResponse['candidates'].isNotEmpty &&
          jsonResponse['candidates'][0]['content'] != null &&
          jsonResponse['candidates'][0]['content']['parts'] != null &&
          jsonResponse['candidates'][0]['content']['parts'].isNotEmpty) {
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return 'Error: Invalid response structure from API.';
      }
    } else {
      return 'Error: ${response.statusCode} - $responseBody';
    }
  } on TimeoutException catch (_) {
    return 'Error: The request to the server timed out. Please try again.';
  } catch (e) {
    return 'Error making API call: $e';
  } finally {
    // It's crucial to close the HttpClient to free up resources.
    client?.close();
  }
}

class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  Future<String> generateContent(
    List<ChatMessage> messages,
    String model,
  ) async {
    final messagesAsJson = messages.map((m) => m.toJson()).toList();

    return compute(_generateContentIsolate, {
      'apiKey': apiKey,
      'model': model,
      'messages': messagesAsJson,
    });
  }
}