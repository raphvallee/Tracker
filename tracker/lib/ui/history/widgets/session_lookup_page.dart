import 'package:flutter/material.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';

/// Resolve a calendar ID only when opened; FutureBuilder rejects obsolete
/// completions on repository replacement, retry, and route disposal.
class SessionLookupPage extends StatefulWidget {
  const SessionLookupPage({
    super.key,
    required this.id,
    required this.gymNames,
  });

  final int id;
  final Map<int, String> gymNames;

  @override
  State<SessionLookupPage> createState() => _SessionLookupPageState();
}

class _SessionLookupPageState extends State<SessionLookupPage> {
  WorkoutSessionRepository? _repository;
  Future<WorkoutSession?>? _lookup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.maybeOf(context)?.sessions;
    if (_lookup == null || !identical(repository, _repository)) {
      _repository = repository;
      _reload();
    }
  }

  @override
  void didUpdateWidget(covariant SessionLookupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _reload();
  }

  void _reload() {
    final repository = _repository;
    _lookup = Future.sync(() => repository?.getById(widget.id));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WorkoutSession?>(
    key: ObjectKey(_repository),
    future: _lookup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          snapshot.data != null) {
        final session = snapshot.data!;
        return SessionDetailPage(
          session: session,
          gymName: widget.gymNames[session.gymId],
        );
      }
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            CustomAppBar(context, title: 'Workout'),
            SliverFillRemaining(
              hasScrollBody: false,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          snapshot.hasError
                              ? 'Could not load workout.'
                              : 'This workout no longer exists.',
                        ),
                        TextButton(
                          onPressed: () => setState(_reload),
                          child: const Text('Retry workout'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}
