// lib/core/logging/session_logger.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final String level;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'message': message,
  };

  @override
  String toString() => '[${timestamp.toIso8601String()}] [$level] $message';
}

class SessionLogger {
  SessionLogger({this.maxEntries = 500});

  final int maxEntries;
  final List<LogEntry> _entries = <LogEntry>[];
  File? _logFile;

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  String get allLogsAsText => _entries.map((e) => e.toString()).join('\n');

  void info(String message) => _add('INFO', message);
  void debug(String message) => _add('DEBUG', message);
  void warning(String message) => _add('WARN', message);
  void error(String message) => _add('ERROR', message);

  String exportAsJson() =>
      jsonEncode(_entries.map((entry) => entry.toJson()).toList());

  void clear() => _entries.clear();

  Future<void> initFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/VPSEmerald/logs/app.log';
      _logFile = File(path);
      await _logFile!.parent.create(recursive: true);
    } catch (e) {
      stderr.writeln('[SessionLogger] failed to init file: $e');
    }
  }

  void _add(String level, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      message: message,
    );
    _entries.add(entry);

    // Print to stderr for debugging (visible in IDE console)
    stderr.writeln(entry.toString());

    // Also append to file
    _logFile?.writeAsString('${entry.toString()}\n', mode: FileMode.append);

    // Trim if exceeds max
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }
}
