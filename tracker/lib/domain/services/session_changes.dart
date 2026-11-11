import 'package:tracker/domain/models/session_draft.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';

/// The saved set [set] was opened from, or null for a set added in the
/// draft.
WorkoutSet? savedSetOf(WorkoutSession saved, SetDraft set) {
  final origin = set.origin;
  if (origin == null || origin < 0 || origin >= saved.sets.length) return null;
  return saved.sets[origin];
}

/// Whether [set] saves other values than the saved set it was opened from.
/// A set added in the draft is new, not edited.
bool isEditedSet(WorkoutSession saved, SetDraft set) {
  final before = savedSetOf(saved, set);
  return before != null && set.differsFrom(before);
}

/// The changes [draft] makes to [saved], one per thing the user would undo
/// on its own: the name, the gym, each time, and every set edited, added or
/// removed. Zero when saving would write [saved] back unchanged.
int sessionChangeCount(WorkoutSession saved, SessionDraft draft) {
  var count = 0;
  if (draft.title.trim() != saved.title) count++;
  if (draft.gymId != saved.gymId) count++;
  if (!draft.startTime.isAtSameMomentAs(saved.startTime)) count++;
  if (!_sameMoment(draft.endTime, saved.endTime)) count++;
  final kept = <int>{};
  for (final set in draft.sets) {
    final before = savedSetOf(saved, set);
    if (before == null) {
      count++;
      continue;
    }
    kept.add(set.origin!);
    if (set.differsFrom(before)) count++;
  }
  return count + saved.sets.length - kept.length;
}

bool _sameMoment(DateTime? a, DateTime? b) =>
    a == null || b == null ? a == b : a.isAtSameMomentAs(b);
