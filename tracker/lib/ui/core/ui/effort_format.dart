import 'package:flutter/widgets.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

/// The effort scale Settings picked: sets store RPE, the UI shows this.
EffortScale effortScaleOf(BuildContext context) =>
    SettingsCubit.maybeOf(context)?.state.effortScale ?? EffortScale.rpe;

/// A stored RPE on [scale], as a bare number: "8", "2".
String formatEffort(EffortScale scale, double rpe) =>
    formatDecimal(scale.fromRpe(rpe));

/// "RPE 8", "RIR 2".
String effortLabel(EffortScale scale, double rpe) =>
    '${scale.label} ${formatEffort(scale, rpe)}';
