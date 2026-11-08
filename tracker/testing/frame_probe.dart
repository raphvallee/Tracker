import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';

/// Counts the frames rendered after an interaction until [visible] holds at
/// the end of a frame (checked in a post-frame callback, so the check never
/// runs inside the frame it measures).
///
/// Never schedules frames itself: if the app sits idle waiting on async work,
/// no frame is counted, which is what the user sees too.
class FrameProbe {
  FrameProbe._(this._visible);

  /// Starts counting from now; call right before dispatching the interaction.
  factory FrameProbe.start(bool Function() visible) {
    final probe = FrameProbe._(visible).._watch.start();
    SchedulerBinding.instance.addPostFrameCallback(probe._onFrame);
    return probe;
  }

  final bool Function() _visible;
  final Stopwatch _watch = Stopwatch();
  final Completer<void> _done = Completer<void>();

  /// Engine frame numbers (matching [FrameTiming.frameNumber]) of every frame
  /// rendered until the condition held, in order.
  final List<int> frameNumbers = <int>[];

  /// Microseconds from [FrameProbe.start] to the end of the frame that first
  /// satisfied the condition.
  int? hitMicros;

  int get frames => frameNumbers.length;

  Future<void> get done => _done.future;

  void _onFrame(Duration _) {
    frameNumbers.add(PlatformDispatcher.instance.frameData.frameNumber);
    // Stamp before the check: the condition (usually a finder walk) is test
    // overhead, not app time.
    final elapsed = _watch.elapsedMicroseconds;
    if (_visible()) {
      hitMicros = elapsed;
      _done.complete();
    } else {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    }
  }
}

/// Collects engine [FrameTiming]s by frame number while installed.
class FrameTimingLog {
  FrameTimingLog() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  final Map<int, FrameTiming> _byFrame = <int, FrameTiming>{};

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _byFrame[t.frameNumber] = t;
    }
  }

  /// UI-thread build+layout+paint time of each listed frame that has been
  /// reported so far, in microseconds.
  List<int> buildMicros(Iterable<int> frameNumbers) => [
    for (final n in frameNumbers)
      if (_byFrame[n] case final t?) t.buildDuration.inMicroseconds,
  ];

  /// Heaviest UI-thread frame among all reported frames numbered in
  /// [from, to], in microseconds (0 if none).
  int maxBuildBetween(int from, int to) {
    var max = 0;
    for (final entry in _byFrame.entries) {
      if (entry.key < from || entry.key > to) continue;
      final us = entry.value.buildDuration.inMicroseconds;
      if (us > max) max = us;
    }
    return max;
  }

  int get latestFrame =>
      _byFrame.isEmpty ? -1 : _byFrame.keys.reduce((a, b) => a > b ? a : b);

  void dispose() => SchedulerBinding.instance.removeTimingsCallback(_onTimings);
}
