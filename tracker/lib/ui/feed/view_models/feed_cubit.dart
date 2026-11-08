import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/workout_session.dart';

enum FeedStatus { loading, ready, error }

class FeedState {
  const FeedState({this.status = FeedStatus.loading, this.sessions = const []});

  final FeedStatus status;
  final List<WorkoutSession> sessions;
}

class FeedCubit extends Cubit<FeedState> {
  FeedCubit({this.repository}) : super(const FeedState());

  final TrackerRepository? repository;

  StreamSubscription<List<WorkoutSession>>? _subscription;

  void load({int limit = 3}) {
    final repo = repository;
    if (repo == null) return;
    unawaited(_subscribe(repo, limit));
  }

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
