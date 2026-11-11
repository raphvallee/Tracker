import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/graph_config.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/services/graph_series.dart';
import 'package:tracker/ui/analytics/view_models/analytics_data.dart';
import 'package:tracker/ui/analytics/widgets/graph_editor.dart';
import 'package:tracker/ui/analytics/widgets/graph_range_control.dart';
import 'package:tracker/ui/analytics/widgets/graph_readout.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/graph_chart.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

/// One graph, full screen: the headline, the chart (tap, drag or hold to
/// read a session or a week), the range, and the sessions behind it, each
/// opening its past workout. Its menu edits or deletes the graph.
class GraphPage extends StatefulWidget {
  const GraphPage({super.key, required this.index, required this.data});

  /// The graph's place in the saved graphs.
  final int index;

  /// What the Feed read; read again after a past workout was opened.
  final AnalyticsData data;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  late AnalyticsData _data = widget.data;
  int? _read;

  Future<void> _reload() async {
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    try {
      final data = await AnalyticsData.load(repo);
      if (!mounted) return;
      setState(() {
        _data = data;
        _read = null;
      });
    } catch (error, stackTrace) {
      AppLog.error('graph-page', error, stackTrace);
    }
  }

  Future<void> _openSession(GraphSession point) async {
    final session = _data.session(point.sessionId);
    if (session == null) return;
    final gymId = session.gymId;
    await pushTo<void>(
      context,
      SessionDetailPage(
        session: session,
        gymName: gymId == null ? null : _data.gymNames[gymId],
      ),
    );
    // The workout may have been edited or deleted there.
    if (mounted) await _reload();
  }

  Future<void> _edit(GraphConfig config) async {
    final result = await GraphEditor.show(
      context,
      initial: config,
      exercises: _data.exercises,
    );
    if (!mounted || result == null) return;
    setState(() => _read = null);
    SettingsCubit.maybeOf(context)?.updateGraph(widget.index, result);
  }

  Future<void> _delete(GraphConfig config) async {
    final settings = SettingsCubit.maybeOf(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete graph?',
      message:
          'Remove ${_data.exerciseName(config.exerciseId)} · '
          '${graphMetricLabel(config.metric)} from the Feed? You can add it '
          'again with Add graph.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    // Leave first: this page shows the graph by its place in the list.
    Navigator.of(context).pop();
    settings?.removeGraph(widget.index);
  }

  void _setRange(GraphTimeframe range) {
    setState(() => _read = null);
    SettingsCubit.maybeOf(context)?.setGraphRange(range);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsCubit.maybeOf(context);
    if (settings == null) return const SizedBox.shrink();
    return BlocBuilder<SettingsCubit, SettingsState>(
      bloc: settings,
      builder: (context, state) {
        if (widget.index >= state.graphs.length) {
          return const SizedBox.shrink();
        }
        final config = state.graphs[widget.index];
        return _body(context, config, _data.graph(config, state.graphRange));
      },
    );
  }

  Widget _body(BuildContext context, GraphConfig config, GraphSeries series) {
    final theme = context.theme;
    final name = _data.exerciseName(config.exerciseId);
    final sessions = series.sessions.reversed.toList();
    final nothing =
        series.isEmpty &&
        !(series.metric == GraphMetric.record1rm && series.bestBefore != null);
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: name, trailing: _menu(config)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    graphMetricLabel(config.metric),
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GraphHeadlineView(
                    headline: graphHeadline(context, series, selected: _read),
                  ),
                  const SizedBox(height: 16),
                  if (nothing)
                    SizedBox(
                      height: _chartHeight,
                      child: Center(
                        child: Text(
                          series.bestBefore == null
                              ? 'Log $name in a workout to fill this graph.'
                              : 'Nothing in this range. Try a longer one.',
                          textAlign: TextAlign.center,
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                    )
                  else
                    GraphChart(
                      series: series,
                      unit: weightUnitOf(context),
                      height: _chartHeight,
                      onSelect: (read) => setState(() => _read = read),
                    ),
                  const SizedBox(height: 14),
                  GraphRangeControl(value: series.range, onChange: _setRange),
                  if (sessions.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Sessions',
                            style: theme.typography.body.md.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${sessions.length} ${graphRangeWords(series)}',
                          style: theme.typography.body.xs.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (sessions.isNotEmpty)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              // The same width as the column above (MaxWidth).
              padding: EdgeInsets.symmetric(
                horizontal: math.max(
                  16,
                  (constraints.crossAxisExtent - MaxWidth.defaultMaxWidth) / 2,
                ),
              ),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                sliver: SliverPadding(
                  padding: const EdgeInsets.all(4),
                  sliver: SliverList.separated(
                    itemCount: sessions.length,
                    itemBuilder: (context, i) =>
                        _sessionRow(context, series.metric, sessions[i]),
                    separatorBuilder: (context, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: theme.colors.border),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  static const double _chartHeight = 220;

  Widget _sessionRow(
    BuildContext context,
    GraphMetric metric,
    GraphSession point,
  ) {
    final theme = context.theme;
    final set = point.set;
    final volume = metric == GraphMetric.volume;
    return FItem(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              shortDateLabel(point.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (point.isRecord && !volume) ...[
            const SizedBox(width: 6),
            const RecordTag(),
          ],
        ],
      ),
      subtitle: Text(point.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      suffix: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            volume
                ? formatVolume(context, point.value)
                : '${graphNumber(context, metric, point.value)} '
                      '${weightUnitOf(context).symbol}',
            style: theme.typography.body.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colors.foreground,
            ),
          ),
          Text(
            volume || set == null
                ? plural('set', point.sets)
                : '${formatWeight(context, set.weight)} × '
                      '${formatReps(set.reps)}',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
      onPress: () => _openSession(point),
    );
  }

  Widget _menu(GraphConfig config) => FPopoverMenu.tiles(
    menuAnchor: .topRight,
    childAnchor: .bottomRight,
    menuBuilder: (menuContext, controller, _) => [
      .group(
        children: [
          .tile(
            prefix: const Icon(FLucideIcons.pencil),
            title: const Text('Edit graph'),
            onPress: () {
              controller.hide();
              _edit(config);
            },
          ),
          .tile(
            prefix: const Icon(FLucideIcons.trash2),
            title: const Text('Delete graph'),
            onPress: () {
              controller.hide();
              _delete(config);
            },
          ),
        ],
      ),
    ],
    builder: (_, controller, _) => AppIconButton(
      icon: FLucideIcons.ellipsis,
      tooltip: 'Graph options',
      onPress: controller.toggle,
    ),
  );
}
