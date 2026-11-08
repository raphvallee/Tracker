// Must be invoked inside `tester.runAsync(...)` - engine font registration is
// real async and never completes in the testWidgets fake-async zone.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() => _pending ??= _load();
Future<void>? _pending;

Future<void> _load() async {
  final hosted = _pubCacheHostedDir();
  if (hosted == null) {
    print('FONTS: pub cache not found - text falls back to the test font.');
    await _loadSdkFonts();
    return;
  }

  final foruiDir = _findPackageDir(hosted, 'forui-');
  final fontDir = foruiDir == null
      ? null
      : Directory(
          '${foruiDir.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}fonts${Platform.pathSeparator}inter',
        );
  if (fontDir == null || !fontDir.existsSync()) {
    print(
      'FONTS: Inter not found in pub cache - text stays on the wider test font.',
    );
  } else {
    for (final name in ['Inter.ttf', 'Inter-Italic.ttf']) {
      final file = File('${fontDir.path}${Platform.pathSeparator}$name');
      if (!file.existsSync()) continue;
      final data = await file.readAsBytes();
      final loader = FontLoader('packages/forui/Inter')
        ..addFont(Future.value(ByteData.view(data.buffer)));
      await loader.load();
    }
    print('FONTS: Inter loaded from ${fontDir.path}');
  }

  // Lucide icons: register under both family names that can be requested -
  // the plain name (what FLucideIcons' IconData constants carry) and the
  // package-prefixed name (what FontManifest registers in real builds).
  final lucideDir = _findPackageDir(hosted, 'forui_lucide-');
  final lucideFile = lucideDir == null
      ? null
      : File(
          '${lucideDir.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}lucide.ttf',
        );
  if (lucideFile == null || !lucideFile.existsSync()) {
    print('FONTS: lucide.ttf not found in pub cache - icons render as tofu.');
  } else {
    final data = await lucideFile.readAsBytes();
    for (final family in [
      'ForuiLucideIcons',
      'packages/forui_lucide/ForuiLucideIcons',
    ]) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(data.buffer)));
      await loader.load();
    }
    print('FONTS: Lucide icons loaded from ${lucideFile.path}');
  }

  await _loadSdkFonts();
}

Future<void> _loadSdkFonts() async {
  final fontsDir = _sdkFontsDir();
  if (fontsDir == null) {
    print(
      'FONTS: Flutter SDK font dir not found - '
      'MaterialIcons/Roboto may render as tofu.',
    );
    return;
  }
  await _loadFontFamily(
    File('${fontsDir.path}${Platform.pathSeparator}materialicons-regular.otf'),
    'MaterialIcons',
  );
  final roboto = File(
    '${fontsDir.path}${Platform.pathSeparator}roboto-regular.ttf',
  );
  await _loadFontFamily(roboto, 'Roboto');
  // Material's platform typography pins 'Segoe UI' on Windows (e.g.
  // FlexibleSpaceBar titles under the windows platform override); the test
  // env has no system fonts, so alias it to the shipped Roboto glyphs.
  await _loadFontFamily(roboto, 'Segoe UI');
}

Future<void> _loadFontFamily(File file, String family) async {
  if (!file.existsSync()) {
    print('FONTS: ${file.path} not found - $family renders as tofu.');
    return;
  }
  final data = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(data.buffer)));
  await loader.load();
  print('FONTS: $family loaded from ${file.path}');
}

Directory? _pubCacheHostedDir() {
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}${Platform.pathSeparator}Pub${Platform.pathSeparator}Cache'
          : '${Platform.environment['HOME']}${Platform.pathSeparator}.pub-cache');
  final hosted = Directory(
    '$pubCache${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev',
  );
  return hosted.existsSync() ? hosted : null;
}

Directory? _findPackageDir(Directory hosted, String fragment) {
  for (final entity in hosted.listSync()) {
    if (entity is Directory && entity.path.contains(fragment)) return entity;
  }
  return null;
}

Directory? _sdkFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory(
      '$root${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts',
    );
    if (dir.existsSync()) return dir;
  }
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    final candidate = Directory(
      '${dir.path}${Platform.pathSeparator}material_fonts',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
