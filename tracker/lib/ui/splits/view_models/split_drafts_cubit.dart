import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';

/// A split being edited: the saved version editing started from, and the
/// edited one.
class SplitDraftEntry {
  const SplitDraftEntry({required this.base, required this.draft});

  static SplitDraftEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final base = json['base'];
    final draft = json['draft'];
    if (base is! Map || draft is! Map) return null;
    return SplitDraftEntry(
      base: SplitDraft.fromJson(Map<String, dynamic>.from(base)),
      draft: SplitDraft.fromJson(Map<String, dynamic>.from(draft)),
    );
  }

  final SplitDraft base;
  final SplitDraft draft;

  Map<String, dynamic> toJson() => {
    'base': base.toJson(),
    'draft': draft.toJson(),
  };
}

class SplitDraftsState {
  SplitDraftsState([Map<int, SplitDraftEntry> entries = const {}])
    : entries = Map.unmodifiable(entries);

  factory SplitDraftsState.fromJson(Map<String, dynamic> json) {
    // Hydrated-state schema versioning, as WorkoutState/SettingsState: unknown
    // versions fall back to no drafts instead of crashing.
    switch (json['v'] as int? ?? 1) {
      case 1:
        final raw = json['entries'];
        return SplitDraftsState({
          if (raw is List)
            for (final entry in raw.map(SplitDraftEntry.fromJson).nonNulls)
              entry.draft.splitId: entry,
        });
      default:
        return SplitDraftsState();
    }
  }

  /// By split id. A split only has an entry while its draft differs from
  /// the saved version.
  final Map<int, SplitDraftEntry> entries;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'entries': [for (final entry in entries.values) entry.toJson()],
  };
}

/// Unsaved split edits. Every edit lands in a draft that is kept across app
/// restarts; [save] writes a draft to the database, [discard] drops it.
class SplitDraftsCubit extends HydratedCubit<SplitDraftsState> {
  SplitDraftsCubit({this.repository}) : super(SplitDraftsState());

  final TrackerRepository? repository;

  /// [saved]'s draft, or [saved] itself when it has none. [fallback] seeds
  /// exercises saved before planned sets existed.
  SplitDraft draftOf(WorkoutSplit saved, {SetTarget? fallback}) =>
      state.entries[saved.id]?.draft ?? _fromSplit(saved, fallback);

  /// The saved version [saved]'s draft is compared with.
  SplitDraft baseOf(WorkoutSplit saved, {SetTarget? fallback}) =>
      state.entries[saved.id]?.base ?? _fromSplit(saved, fallback);

  void edit(
    WorkoutSplit saved,
    SplitDraft Function(SplitDraft draft) change, {
    SetTarget? fallback,
  }) {
    final entry = state.entries[saved.id];
    final base = entry?.base ?? _fromSplit(saved, fallback);
    final draft = change(entry?.draft ?? base);
    final entries = {...state.entries};
    if (draft == base) {
      entries.remove(saved.id);
    } else {
      entries[saved.id] = SplitDraftEntry(base: base, draft: draft);
    }
    emit(SplitDraftsState(entries));
  }

  /// Writes [splitId]'s draft to the database and drops it. A failed write
  /// throws and keeps the draft.
  Future<void> save(int splitId) async {
    final entry = state.entries[splitId];
    if (entry == null) return;
    final repo = repository;
    if (repo != null) {
      final saved = await repo.splits.getById(splitId);
      if (saved != null) {
        entry.draft.writeTo(saved);
        await repo.splits.put(saved);
      }
    }
    discard(splitId);
  }

  void discard(int splitId) {
    if (!state.entries.containsKey(splitId)) return;
    emit(SplitDraftsState({...state.entries}..remove(splitId)));
  }

  static SplitDraft _fromSplit(WorkoutSplit saved, SetTarget? fallback) =>
      fallback == null
      ? SplitDraft.fromSplit(saved)
      : SplitDraft.fromSplit(saved, fallback: fallback);

  @override
  SplitDraftsState? fromJson(Map<String, dynamic> json) =>
      SplitDraftsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SplitDraftsState state) => state.toJson();
}
