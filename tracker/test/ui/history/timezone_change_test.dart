import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';

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
      model.updateSessions([session]);
      expect(model.dateIndex.sessionsOn(DateTime(2025, 7, 1)), [session]);
      zone('America/Phoenix');
      expect(clock.toLocal().timeZoneName, anchor.timeZoneName);
      expect(clock.toLocal().timeZoneOffset, anchor.timeZoneOffset);
      model.setActive(true);
      expect(model.dateIndex.sessionsOn(DateTime(2025, 6, 30)), [session]);
      expect(model.dateIndex.monthWorkoutDays(2025, 7), 0);
      model.setActive(false);
    },
    skip: !Platform.isMacOS && !Platform.isLinux,
  );
}
