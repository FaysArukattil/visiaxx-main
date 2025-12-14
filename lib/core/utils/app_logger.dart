import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static Logger? _logger;
  static File? _logFile;
  static bool _isInitialized = false;

  static Future initialize() async {
    if (_isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/vision_test_speech.log');

      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 0,
          lineLength: 200,
          colors: false,
          printEmojis: false,
          printTime: true,
        ),
        output: MultiOutput([ConsoleOutput(), FileOutput(file: _logFile!)]),
      );

      _isInitialized = true;
      print('[AppLogger] ✅ Initialized. Log file: ${_logFile!.path}');
    } catch (e) {
      print('[AppLogger] ❌ Initialization failed: $e');
    }
  }

  /// Log long distance test (E plates)
  static void logLongDistance({
    required String eye,
    required int plateNumber,
    required String snellen,
    required double fontSize,
    required String expected,
    required String userSaid,
    required bool correct,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final message =
        'Speech Recognition [Long Distance] | Eye: $eye | Plate: $plateNumber/7 | '
        'Snellen: $snellen | Font Size: ${fontSize}sp | Expected: $expected | '
        'User Said: "$userSaid" | System Heard: "$userSaid" | Correct: $correct';

    _logger?.e(message);
    _writeToFile('[$timestamp] [ERROR] $message');
  }

  /// Log short distance test (sentences)
  static void logShortDistance({
    required int screenNumber,
    required String snellen,
    required double fontSize,
    required String expected,
    required String userSaid,
    required double similarity,
    required bool pass,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final message =
        'Speech Recognition [Short Distance] | Screen: $screenNumber/7 | '
        'Snellen: $snellen | Font Size: ${fontSize}sp | '
        'Expected: "$expected" | User Said: "$userSaid" | '
        'Similarity: ${similarity.toStringAsFixed(1)}% | Pass: $pass';

    _logger?.e(message);
    _writeToFile('[$timestamp] [ERROR] $message');
  }

  /// Write directly to file
  static void _writeToFile(String message) {
    try {
      _logFile?.writeAsStringSync('$message\n', mode: FileMode.append);
    } catch (e) {
      print('[AppLogger] Write error: $e');
    }
  }

  /// Get log file path
  static String? get logFilePath => _logFile?.path;

  /// Read all logs
  static Future readLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      print('[AppLogger] Read error: $e');
    }
    return 'No logs available';
  }

  /// Clear all logs
  static Future clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        print('[AppLogger] Logs cleared');
      }
    } catch (e) {
      print('[AppLogger] Clear error: $e');
    }
  }
}

/// Custom file output for Logger
class FileOutput extends LogOutput {
  final File file;

  FileOutput({required this.file});

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      try {
        file.writeAsStringSync('$line\n', mode: FileMode.append);
      } catch (_) {}
    }
  }
}
