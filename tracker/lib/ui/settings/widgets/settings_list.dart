import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';

// The building blocks every settings page is made of: a page of
// SettingsSections, each a card of rows. A row is a link to another page
// (SettingsLinkItem), a switch (SettingsSwitchItem), a choice that opens a
// sheet of explained options (SettingsChoiceItem) or a value with its own
// editor (SettingsValueItem). A new setting is one row in a section; a
// section that outgrows its page moves to a page of its own behind a link.

/// A settings page: a pinned header over its sections, at a readable width.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: title),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.separated(
            itemCount: sections.length,
            itemBuilder: (context, i) => MaxWidth(child: sections[i]),
            separatorBuilder: (_, _) => const SizedBox(height: 28),
          ),
        ),
      ],
    );
  }
}

/// A group of related rows in one card, with an optional heading above and
/// a note below that explains the group.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  final String? title;
  final String? footer;
  final List<FItemMixin> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title case final title?)
          Padding(
            padding: const EdgeInsets.only(left: _textInset, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ItemCard(children: children),
        if (footer case final footer?)
          Padding(
            padding: const EdgeInsets.fromLTRB(_textInset, 8, _textInset, 0),
            child: Text(footer, style: _note(context)),
          ),
      ],
    );
  }
}

/// A row that opens another page; [summary] says what is set there.
class SettingsLinkItem extends StatelessWidget with FItemMixin {
  const SettingsLinkItem({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.onPress,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) => FItem(
    prefix: Icon(icon),
    title: Text(title),
    subtitle: _wrapping(summary),
    suffix: const Icon(FLucideIcons.chevronRight),
    onPress: onPress,
  );
}

/// A row with a switch; tapping anywhere on it flips the switch.
class SettingsSwitchItem extends StatelessWidget with FItemMixin {
  const SettingsSwitchItem({
    super.key,
    required this.title,
    this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => FItem(
    title: Text(title),
    subtitle: description == null ? null : _wrapping(description!),
    suffix: FSwitch(value: value, onChange: onChanged),
    onPress: () => onChanged(!value),
  );
}

/// One option of a [SettingsChoiceItem]: what it is called and what picking
/// it does.
class SettingOption<T> {
  const SettingOption(this.value, this.label, this.description);

  final T value;
  final String label;
  final String description;
}

/// A row showing the chosen option; tapping it opens a sheet listing every
/// option with what it does. Picking one applies it and closes the sheet.
class SettingsChoiceItem<T> extends StatelessWidget with FItemMixin {
  const SettingsChoiceItem({
    super.key,
    required this.title,
    this.description,
    required this.options,
    required this.value,
    required this.onChanged,
    this.sheetNote,
  });

  final String title;
  final String? description;
  final List<SettingOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Shown under the options in the sheet.
  final String? sheetNote;

  Future<void> _open(BuildContext context) async {
    final picked = await showChoiceSheet<T>(
      context,
      title: title,
      description: description,
      options: options,
      value: value,
      note: sheetNote,
    );
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => _valueRow(
    context,
    title: title,
    description: description,
    value: optionOf(options, value).label,
    onPress: () => _open(context),
  );
}

/// A row showing a value that [onPress] edits, e.g. in a sheet of its own.
class SettingsValueItem extends StatelessWidget with FItemMixin {
  const SettingsValueItem({
    super.key,
    required this.title,
    this.description,
    required this.value,
    required this.onPress,
  });

  final String title;
  final String? description;
  final String value;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) => _valueRow(
    context,
    title: title,
    description: description,
    value: value,
    onPress: onPress,
  );
}

/// The option of [options] holding [value].
SettingOption<T> optionOf<T>(List<SettingOption<T>> options, T value) =>
    options.firstWhere((option) => option.value == value);

/// Lists [options] with what each does, [value] checked: one tap picks and
/// closes. Null when dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? description,
  required List<SettingOption<T>> options,
  required T value,
  String? note,
}) {
  return showFSheet<T>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.9,
    builder: (sheetContext) => SheetSurface(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: sheetContext.theme.typography.body.lg.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(description, style: _note(sheetContext)),
          ],
          const SizedBox(height: 14),
          ItemCard(
            divider: .full,
            children: <FItemMixin>[
              for (final option in options)
                FItem(
                  selected: option.value == value,
                  semanticsInMutuallyExclusiveGroup: true,
                  title: Text(
                    option.label,
                    style: option.value == value
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null,
                  ),
                  subtitle: _wrapping(option.description),
                  suffix: option.value == value
                      ? const Icon(FLucideIcons.check)
                      : const SizedBox(width: 16),
                  onPress: () => Navigator.of(sheetContext).pop(option.value),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note, style: _note(sheetContext)),
          ],
        ],
      ),
    ),
  );
}

/// How far row text sits inside its card; headings and notes line up with it.
const double _textInset = 14;

/// A row with its value and a chevron on the title line, and the
/// description below at full width. FItem's own layout drops the value
/// when the description wraps.
FItem _valueRow(
  BuildContext context, {
  required String title,
  String? description,
  required String value,
  required VoidCallback onPress,
}) {
  final theme = context.theme;
  final muted = theme.colors.mutedForeground;
  return FItem.raw(
    onPress: onPress,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title)),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              FLucideIcons.chevronRight,
              color: muted,
              size: theme.typography.body.md.fontSize,
            ),
          ],
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(description, style: _note(context)),
          ),
      ],
    ),
  );
}

/// A row's explanation, wrapped in full: FItem cuts it to one line otherwise.
Widget _wrapping(String text) => Text(
  text,
  softWrap: true,
  overflow: TextOverflow.visible,
  style: const TextStyle(height: 1.35),
);

TextStyle _note(BuildContext context) => context.theme.typography.body.xs
    .copyWith(color: context.theme.colors.mutedForeground, height: 1.35);
