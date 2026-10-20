import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/workout_session.dart';

/// Load status of the feed's recent-activity list.
enum FeedStatus { loading, ready, error }

/// State of the recent-activity feed: a spinner while the first event is in
/// flight, the watched sessions once ready, or an error when the repository
/// stream failed.
class FeedState {
  const FeedState({this.status = FeedStatus.loading, this.sessions = const []});

  final FeedStatus status;
  final List<WorkoutSession> sessions;
}

/// Drives the feed page's recent-activity list.
///
/// The cubit owns the repository subscription so [retry] can cancel the dead
/// one and open a fresh one (a bare `setState` cannot resurrect a failed
/// stream subscription).
class FeedCubit extends Cubit<FeedState> {
  FeedCubit({this.repository}) : super(const FeedState());

  /// Nullable like [WorkoutCubit.repository]: isolate widget tests may pump
  /// the app without a repository scope.
  final TrackerRepository? repository;

  StreamSubscription<List<WorkoutSession>>? _subscription;

  /// Watch the [limit] most recent completed sessions.
  void load({int limit = 3}) {
    final repo = repository;
    if (repo == null) return;
    unawaited(_subscribe(repo, limit));
  }

  /// Re-subscribe after an error with a fresh stream.
  void retry() => load();

  Future<void> _subscribe(TrackerRepository repo, int limit) async {
    await _subscription?.cancel();
    _subscription = null;
    emit(const FeedState());
    try {
      final stream = repo.sessions.watchRecent(limit: limit);
      _subscription = stream.listen(
        (sessions) =>
            emit(FeedState(status: FeedStatus.ready, sessions: sessions)),
        onError: (Object error, StackTrace stackTrace) {
          AppLog.error('feed', error, stackTrace);
          emit(const FeedState(status: FeedStatus.error));
        },
      );
    } catch (error, stackTrace) {
      AppLog.error('feed', error, stackTrace);
      emit(const FeedState(status: FeedStatus.error));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
