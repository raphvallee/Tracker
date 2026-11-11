import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';

void main() {
  final now = DateTime(2026, 11, 10, 12);

  group('date labels', () {
    test('read like "Mon 9 Nov, 18:04", the year only when not this one', () {
      final start = DateTime(2026, 11, 9, 18, 4);
      expect(weekdayLabel(start), 'Mon');
      expect(shortDateLabel(start, now: now), 'Mon 9 Nov');
      expect(timeLabel(DateTime(2026, 1, 1, 7, 5)), '07:05');
      expect(dateTimeLabel(start, now: now), 'Mon 9 Nov, 18:04');
      expect(
        shortDateLabel(DateTime(2025, 12, 31), now: now),
        'Wed 31 Dec 2025',
      );
    });

    test('a range names the end day only when it differs', () {
      final start = DateTime(2026, 11, 9, 18, 4);
      expect(
        timeRangeLabel(start, DateTime(2026, 11, 9, 19, 16), now: now),
        'Mon 9 Nov, 18:04 to 19:16',
      );
      expect(
        timeRangeLabel(
          DateTime(2026, 11, 9, 23, 30),
          DateTime(2026, 11, 10, 0, 40),
          now: now,
        ),
        'Mon 9 Nov, 23:30 to Tue 10 Nov, 00:40',
      );
      expect(timeRangeLabel(start, null, now: now), 'Mon 9 Nov, 18:04');
    });

    test('months read in full, with the year when not this one', () {
      expect(monthName(1), 'January');
      expect(monthLabel(2026, 11, now: now), 'November');
      expect(monthLabel(2025, 12, now: now), 'December 2025');
    });

    test('never fall back to ISO dates', () {
      final label = dateTimeLabel(DateTime(2026, 3, 4, 9), now: now);
      expect(label, isNot(contains('2026-')));
      expect(label, isNot(contains('·')));
    });
  });
}
