import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import 'package:scn_jobs/core/env/app_config.dart';

/// Thin wrapper around `package:logger`.
///
/// - In debug/staging builds: pretty console output + a rotated file under
///   the app's documents directory (`logs/scn_jobs_YYYY-MM-DD.log`).
/// - In release builds: console-only, no file I/O, to avoid burning battery
///   and storage on low-end devices.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      // ignore: avoid_redundant_argument_values
      colors: !AppConfig.isRelease,
      // ignore: avoid_redundant_argument_values
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: AppConfig.isRelease ? ConsoleOutput() : _MultiOutput(),
  );

  static void d(String message) => _logger.d('[${AppConfig.label}] $message');

  static void i(String message) => _logger.i('[${AppConfig.label}] $message');

  static void w(String message) => _logger.w('[${AppConfig.label}] $message');

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(
      '[${AppConfig.label}] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Writes to console and, lazily, to a daily-rotated file — only ever
/// constructed when not in release mode (see [AppLogger._logger]).
class _MultiOutput extends LogOutput {
  final ConsoleOutput _console = ConsoleOutput();
  IOSink? _sink;
  String? _currentLogDate;

  @override
  void output(OutputEvent event) {
    _console.output(event);
    unawaited(_writeToFile(event));
  }

  Future<void> _writeToFile(OutputEvent event) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      if (_currentLogDate != today || _sink == null) {
        await _sink?.flush();
        await _sink?.close();
        final dir = await getApplicationDocumentsDirectory();
        final logsDir = Directory('${dir.path}/logs')
          ..createSync(recursive: true);
        final file = File('${logsDir.path}/scn_jobs_$today.log');
        _sink = file.openWrite(mode: FileMode.append);
        _currentLogDate = today;
      }
      for (final line in event.lines) {
        _sink?.writeln(line);
      }
    } catch (_) {
      // File logging is best-effort — never let a logging failure crash
      // the app or mask the original error being logged.
    }
  }
}
