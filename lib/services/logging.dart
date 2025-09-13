import 'dart:io';

import 'package:arcadia/util.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// A service to configure and manage logging for the application.
///
/// This service sets up a logger that writes messages to a file, with each
/// log file being named with a timestamp to prevent overwrites. It follows the
/// singleton pattern to ensure a single logging instance throughout the app.
class Logging {
  /// The single, static instance of the LoggingService.
  static final Logging _instance = Logging._internal();

  /// The logger instance.
  static final Logger _logger = Logger('ArcadiaLogger');

  /// Private constructor for the singleton pattern.
  Logging._internal();

  /// Factory constructor to return the singleton instance.
  factory Logging() {
    return _instance;
  }

  /// The directory where log files are stored.
  static late Directory logsDir;

  /// Configures the logger to write to a file.
  ///
  /// This method should be called once at application startup. It sets up the
  /// log level and a listener that writes log records to a timestamped file.
  static Future<void> configure() async {
    // Set the logging level to record all messages.
    Logger.root.level = Level.ALL;

    // Get the application's documents directory.
    final logsDir = await getArcadiaDocuments('logs');

    // Generate a timestamped file name for the log file.
    final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');
    final logFile = await File(p.join(logsDir.path, 'arcadia_$timestamp.log')).create();

    // Set up a listener to write log records to the file.
    Logger.root.onRecord.listen((record) {
      String message = '${record.level.name}: ${record.time}: ${record.message}';
      if (record.error != null || record.stackTrace != null) {
        message +=
            '\n${record.error ?? 'Stack Trace'}: ${record.stackTrace ?? '[No stack trace received.]'}';
      }
      // ignore: avoid_print
      print(message); // Also print to console for easy debugging.
      logFile.writeAsStringSync('$message\n', mode: FileMode.append);
    });
  }

  /// Logs a message with the specified log level.
  ///
  /// - [level]: The severity of the log message.
  /// - [message]: The message to be logged.
  /// - [error]: An optional error object to include in the log.
  /// - [stackTrace]: An optional stack trace to include in the log.
  void log(Level level, String message, [Object? error, StackTrace? stackTrace]) {
    _logger.log(level, message, error, stackTrace);
  }

  /// Logs an informational message.
  ///
  /// Use this for general operational messages.
  void info(String message) {
    log(Level.INFO, message);
  }

  /// Logs a warning message.
  ///
  // Use this for potential issues that don't prevent the app from running.
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    log(Level.WARNING, message);
  }

  /// Logs a severe error message.
  ///
  /// Use this for critical errors that may cause the application to fail.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    log(Level.SEVERE, message, error, stackTrace);
  }

  /// Logs an objects data for debugging.
  /// 
  /// Use this as an alternative to "print".
  void dprint(String data, String? name) {
    log(Level.INFO, '$name: \n$data\n', null, null);
  }
}
