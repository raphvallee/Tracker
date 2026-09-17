import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_session_summary.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

class _ResumeRepository extends Fake implements WorkoutSessionRepository {
  int dateWatches = 0;
  int dayWatches = 0;
  @override
  Stream<List<DateTime>> watchStartTimes() {
    dateWatches++;
    return const Stream.empty();
  }

  @override
  Stream<List<WorkoutSessionSummary>> watchSummariesForDate(DateTime day) {
    dayWatches++;
    return const Stream.empty();
  }
}

typedef _Malloc = Pointer<Void> Function(IntPtr);
typedef _Free = Void Function(Pointer<Void>);
typedef _SetEnv = Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Int32);

// A separate test process changes only its own timezone, never the host setting.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resume regroups cached local dates when timezone fingerprints collide',
    () {
      final library = DynamicLibrary.process();
      final malloc = library
          .lookupFunction<_Malloc, Pointer<Void> Function(int)>('malloc');
      final free = library.lookupFunction<_Free, void Function(Pointer<Void>)>(
        'free',
      );
      final setenv = library
          .lookupFunction<
            _SetEnv,
            int Function(Pointer<Uint8>, Pointer<Uint8>, int)
          >('setenv');
      final unsetenv = library
          .lookupFunction<
            Int32 Function(Pointer<Uint8>),
            int Function(Pointer<Uint8>)
          >('unsetenv');
      final tzset = library.lookupFunction<Void Function(), void Function()>(
        'tzset',
      );
      Pointer<Uint8> string(String value) {
        final bytes = utf8.encode(value);
        final pointer = malloc(bytes.length + 1).cast<Uint8>();
        pointer.asTypedList(bytes.length + 1).setAll(0, [...bytes, 0]);
        return pointer;
      }

      void zone(String? value) {
        final key = string('TZ');
        final data = value == null ? null : string(value);
        try {
          expect(data == null ? unsetenv(key) : setenv(key, data, 1), 0);
          tzset();
        } finally {
          free(key.cast());
          if (data != null) free(data.cast());
        }
      }

      final original = Platform.environment['TZ'];
      addTearDown(() => zone(original));
      zone('America/Denver');
      final clock = DateTime.utc(2026, 1, 15, 12);
      final anchor = clock.toLocal();
      final model = CalendarViewModel(now: () => clock);
      addTearDown(model.dispose);
      final session = WorkoutSession(
        startTime: DateTime.utc(2025, 7, 1, 6, 30).toLocal(),
      );
      // Initially this instant remains July 1 in both zones. Moving it earlier
      // keeps Denver's date counts equal, but must refresh timezone validation.
      session.startTime = DateTime.utc(2025, 7, 1, 8).toLocal();
      model.updateSessions([session]);
      final index = model.dateIndex;
      final days = model.daysWithWorkouts;
      session.startTime = DateTime.utc(2025, 7, 1, 6, 30).toLocal();
      model.updateSessions([session]);
      expect(model.dateIndex, same(index));
      expect(model.daysWithWorkouts, same(days));
      expect(model.dateIndex.countOn(DateTime(2025, 7, 1)), 1);
      final repository = _ResumeRepository();
      final managed = CalendarViewModel(
        now: () => clock,
        observeAppLifecycle: false,
      );
      addTearDown(managed.dispose);
      managed.setHistoryActive(false);
      managed.bindRepository(repository);
      managed.updateDates([session.startTime]);
      managed.setCalendarMode(true);
      zone('America/Phoenix');
      expect(clock.toLocal().timeZoneName, anchor.timeZoneName);
      expect(clock.toLocal().timeZoneOffset, anchor.timeZoneOffset);
      model.setActive(true);
      expect(model.dateIndex.countOn(DateTime(2025, 6, 30)), 1);
      expect(model.dateIndex.monthWorkoutDays(2025, 7), 0);
      model.setActive(false);
      managed.setHistoryActive(true);
      expect(managed.dateIndex.countOn(DateTime(2025, 6, 30)), 1);
      expect(repository.dateWatches, 1);
      expect(repository.dayWatches, 1); // No extra day retry while regrouping.
      managed.setHistoryActive(false);
    },
    skip: !Platform.isMacOS && !Platform.isLinux,
  );
}
