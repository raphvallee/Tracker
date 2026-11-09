import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'start_view.dart';
import 'workout_overview.dart';

/// The Workout tab: what to train next before a workout, the running
/// workout's exercises during one.
class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<WorkoutCubit, WorkoutState>(
      listenWhen: (previous, current) =>
          current.saveError != null && current.saveError != previous.saveError,
      listener: (context, state) => showFToast(
        context: context,
        title: Text(state.saveError!),
        duration: const Duration(seconds: 4),
      ),
      child:
          BlocSelector<
            WorkoutCubit,
            WorkoutState,
            ({bool isInProgress, bool canRestore})
          >(
            selector: (state) => (
              isInProgress: state.isInProgress,
              canRestore:
                  state.canRestoreSaved() || state.canRestoreDiscarded(),
            ),
            builder: (context, view) => view.isInProgress
                ? const WorkoutOverview()
                : StartView(canRestore: view.canRestore),
          ),
    );
  }
}
