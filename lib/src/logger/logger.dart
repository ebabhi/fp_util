library logger;

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';

import 'package:io/ansi.dart';

///{@template log_level}
/// The log level of a log message.
/// {@endtemplate}
enum _LogLevel {
  debug,
  info,
  warning,
  error,
  success;

  @override
  String toString() {
    return switch (this) {
      _LogLevel.debug => 'DEBUG',
      _LogLevel.info => 'INFO',
      _LogLevel.warning => 'WARNING',
      _LogLevel.error => 'ERROR',
      _LogLevel.success => 'SUCCESS',
    };
  }

  /// Returns the label associated with the log level.
  String get label => toString();

  /// Returns the ansi color associated with the log level.
  AnsiCode get color {
    return switch (this) {
      _LogLevel.debug => magenta,
      _LogLevel.info => blue,
      _LogLevel.warning => yellow,
      _LogLevel.error => red,
      _LogLevel.success => green,
    };
  }

  /// Returns the icon associated with the log level.
  String get icon {
    return switch (this) {
      _LogLevel.debug => '🐛',
      _LogLevel.info => 'ℹ',
      _LogLevel.warning => '⚠',
      _LogLevel.error => '✖',
      _LogLevel.success => '✔',
    };
  }
}

/// {@template logger}
/// A simple logger that logs messages to the console.
/// {@endtemplate}
abstract class Logger {
  /// {@macro logger}
  Logger._();

  /// Matches a stacktrace line as generated on Android/iOS devices.
  ///
  static final _deviceStackTraceRegex = RegExp(r'#[0-9]+\s+(.+) \((\S+)\)');

  /// Matches a stacktrace line as generated by Flutter web.
  ///
  static final _webStackTraceRegex = RegExp(r'^((packages|dart-sdk)/\S+/)');

  /// Matches a stacktrace line as generated by browser Dart.
  ///
  /// For example:
  /// * dart:sdk_internal
  static final _browserStackTraceRegex = RegExp(r'^(?:package:)?(dart:\S+|\S+)');

  /// line width of the logger
  static int get _lineWidth => 120;

  /// top border of the logger
  static String get _topBorder => '╔${'═' * _lineWidth}╗';

  /// bottom border of the logger
  static String get _bottomBorder => '╚${'═' * _lineWidth}╝';

  /// side border of the logger
  static String get _sideBorder => '║';

  /// Prints a box with the given lines and level.
  static String _printBox(_LogLevel level, List<String> lines) {
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final content = lines[i];
      final remainingSpace = ' ' * (_lineWidth - (content.length + 1));
      buffer.writeln(level.color.wrap('$content$remainingSpace'));
    }
    return buffer.toString();
  }

  /// prints a line with the given message
  static String _printLine(String line) {
    return '$_sideBorder $line${' ' * (_lineWidth - line.length - 1)}$_sideBorder';
  }

  /// prints a divider
  static String _printDivider() {
    return '╠${'═' * _lineWidth}╣';
  }

  /// Logs a message
  static void _log(
    _LogLevel level,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    bool isError = level == _LogLevel.error && (error != null || stackTrace != null);
    final messages = <String>[
      _topBorder,
      _printLine('${level.icon} | ${level.label} | ${_getTime(DateTime.now())}'),
      _printDivider(),
    ];
    if (message is Map || message is List) {
      try {
        final indentedString = const JsonEncoder.withIndent(' ').convert(message);
        final lines = indentedString.split('\n');
        messages.addAll(lines.map(_printLine));
      } catch (_) {
        messages.add(_printLine(message.toString()));
      }
    } else {
      messages.add(_printLine(message.toString()));
    }
    if (isError) {
      messages.add(_printDivider());
    }
    if (error != null) {
      messages.add(_printLine('ERROR:::'));
      messages.add(_printLine(error.toString()));
    }
    if (stackTrace != null) {
      messages.add(_printLine('STACKTRACE:::'));
      messages.addAll(_formatStackTrace(stackTrace).map(_printLine));
    }
    messages.add(_bottomBorder);
    print(_printBox(level, messages));
  }

  /// formats the stacktrace
  static List<String> _formatStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n').where(
      (element) {
        return !_discardDeviceStacktraceLine(element) && !_discardWebStacktraceLine(element) && !_discardBrowserStacktraceLine(element) && element.isNotEmpty;
      },
    ).toList();

    final formatted = <String>[];
    final stackLength = min(8, lines.length);
    for (int count = 0; count < stackLength; count++) {
      final line = lines[count];
      if (line.isEmpty) {
        continue;
      }
      formatted.add('#$count   ${line.replaceFirst(RegExp(r'#\d+\s+'), '')}');
    }
    return formatted;
  }

  /// Discards stacktrace lines that are not useful.
  static bool _discardDeviceStacktraceLine(String line) {
    var match = _deviceStackTraceRegex.matchAsPrefix(line);
    if (match == null) {
      return false;
    }
    final segment = match.group(2)!;
    return segment.startsWith('package:fp_util');
  }

  /// Discards stacktrace lines that are not useful.
  static bool _discardWebStacktraceLine(String line) {
    var match = _webStackTraceRegex.matchAsPrefix(line);
    if (match == null) {
      return false;
    }
    final segment = match.group(1)!;
    return segment.startsWith('packages/fp_util') || segment.startsWith('dart-sdk/lib');
  }

  /// Discards stacktrace lines that are not useful.
  static bool _discardBrowserStacktraceLine(String line) {
    var match = _browserStackTraceRegex.matchAsPrefix(line);
    if (match == null) {
      return false;
    }
    final segment = match.group(1)!;
    return segment.startsWith('package:fp_util') || segment.startsWith('dart:');
  }

  /// Returns the current time in the format `hh:mm:ss.mmm`.
  static String _getTime(DateTime time) {
    String threeDigits(int n) {
      if (n >= 100) return '$n';
      if (n >= 10) return '0$n';
      return '00$n';
    }

    String twoDigits(int n) {
      if (n >= 12) return '$n';
      return '0$n';
    }

    var now = time;
    var h = twoDigits(now.hour % 12); // convert to 12-hour time
    var min = twoDigits(now.minute);
    var sec = twoDigits(now.second);
    var ms = threeDigits(now.millisecond);
    return '$h:$min:$sec.$ms';
  }

  /// Logs a debug message.
  static void d(dynamic message) {
    _log(_LogLevel.debug, message);
  }

  /// Logs an info message.
  static void i(dynamic message) {
    _log(_LogLevel.info, message);
  }

  /// Logs a warning message.
  static void w(dynamic message) {
    _log(_LogLevel.warning, message);
  }

  /// Logs an error message.
  static void e(
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      _LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs a success message.
  static void s(dynamic message) {
    _log(_LogLevel.success, message);
  }
}
