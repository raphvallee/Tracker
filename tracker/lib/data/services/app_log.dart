import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'app_env.dart';

class AppLog {
  AppLog._();

  static const int maxLines = 500;

  static final List<String> _buffer = <String>[];
  static File? _file;

  /// Serializes mirror-file writes so concurrent appends cannot interleave;
  /// a failed write must never break the chain (or crash the app).
  static Future<void> _pending = Future<void>.value();

  static void init(String directoryPath) {
    _file = File('$directoryPath/tracker.log');
  }

  static void error(String tag, Object error, [StackTrace? stackTrace]) {
    _append('ERR $tag: $error');
    if (stackTrace != null) _append(stackTrace.toString(), indent: true);
  }

  static void debug(String message) {
    if (isProd) return;
    _append('DBG $message');
  }

  static void _append(String message, {bool indent = false}) {
    for (final line in message.split('\n')) {
      if (line.trim().isEmpty) continue;
      _buffer.add(
        indent ? '    $line' : '${DateTime.now().toIso8601String()} $line',
      );
    }
    if (_buffer.length > maxLines) {
      _buffer.removeRange(0, _buffer.length - maxLines);
    }
    _scheduleFlush();
  }

  static void _scheduleFlush() {
    _pending = _pending.then(
      (_) => _flush(),
      onError: (Object _) {}, // keep the chain alive after any failure
    );
  }

  static Future<void> _flush() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.create(recursive: true);
      await file.writeAsString('${_buffer.join('\n')}\n', flush: true);
    } on IOException {
      // Logging must never crash the app; drop the write and keep going.
    }
  }

  @visibleForTesting
  static int get bufferedLines => _buffer.length;

  @visibleForTesting
  static Future<void> get pending => _pending;

  @visibleForTesting
  static void reset() {
    _buffer.clear();
    _file = null;
    _pending = Future<void>.value();
  }
}
