import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_env.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/data/services/db.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/routing/home_page.dart';
import 'package:tracker/ui/core/themes/material_theme_bridge.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

Future<void> main() async {
  return runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Centralized error handling (PRODUCTION_READINESS.md Phase 1): every
    // error channel routes into the local ring-buffer logger. Nothing is
    // ever uploaded off-device.
    FlutterError.onError = (details) {
      AppLog.error('flutter', details.exception, details.stack);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLog.error('platform', error, stack);
      return true;
    };
    ErrorWidget.builder = (details) {
      AppLog.error('widget', details.exception, details.stack);
      return _ErrorFallback(details: details);
    };

    await _bootstrap();
  }, (error, stack) => AppLog.error('zone', error, stack));
}

Future<void> _bootstrap() async {
  // Documents dir hosts both the HydratedBloc storage and the AppLog mirror
  // file, so fetch it once and share it.
  final documentsPath = (await getApplicationDocumentsDirectory()).path;

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(documentsPath),
  );
  AppLog.init(documentsPath);

  // Open the single Isar instance and make the shell available immediately.
  // First-run seeding runs after the first frame, so a slow write cannot delay
  // the initial UI or prevent startup when seeding fails.
  final isar = await DbInstance.getIsar();
  final repository = TrackerRepository(isar);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle("Tracker");
    setWindowMinSize(Size(320, 568));
  }

  runApp(
    RepositoryProvider<TrackerRepository>.value(
      value: repository,
      child: RepositoryScope(
        repository: repository,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>(
              create: (_) => WorkoutCubit(repository: repository),
              lazy: false,
            ),
            BlocProvider<SettingsCubit>(
              create: (_) => SettingsCubit(),
              lazy: false,
            ),
          ],
          child: const MyApp(),
        ),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_seedExercises(repository));
  });
}

Future<void> _seedExercises(
  TrackerRepository repository, {
  int attempt = 0,
}) async {
  try {
    await seedExercisesIfNeeded(repository);
  } catch (error, stackTrace) {
    // Keep startup alive and make the failure observable. If the collection is
    // still empty, retry once after transient startup/IO failures. The report
    // flows through FlutterError.onError into the AppLog ring buffer.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'tracker startup',
        context: ErrorDescription(
          'seeding the exercise library (attempt ${attempt + 1})',
        ),
      ),
    );
    if (attempt == 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _seedExercises(repository, attempt: 1);
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    /// Try changing this and hot reloading the application.
    ///
    /// To create a custom theme:
    /// ```shell
    /// dart forui theme create
    /// ```
    final (lightTheme, darkTheme) =
        const <TargetPlatform>{
          .android,
          .iOS,
          .fuchsia,
        }.contains(defaultTargetPlatform)
        ? (FTheme.neutral.light.touch, FTheme.neutral.dark.touch)
        : (FTheme.neutral.light.desktop, FTheme.neutral.dark.desktop);
    final (navLightTheme, navDarkTheme) = (
      strengthenNavLabels(lightTheme),
      strengthenNavLabels(darkTheme),
    );

    return MaterialApp(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // resizeToAvoidBottomInset: false — do not shrink the whole app for the
      // on-screen keyboard (Forui FScaffold defaults to true, which pushed the
      // entire shell, bottom nav included, up onto the keyboard). Pages pad
      // their scrollable content by the keyboard inset instead; see
      // ui/core/ui/keyboard_inset.dart.
      home: const FScaffold(
        resizeToAvoidBottomInset: false,
        childPad: false,
        child: HomePage(),
      ),
      theme: navLightTheme.toCustomMaterialTheme(),
      darkTheme: navDarkTheme.toCustomMaterialTheme(),
      builder: (context, child) => FTheme(
        data: Theme.brightnessOf(context) == Brightness.light
            ? navLightTheme
            : navDarkTheme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Rendered in place of widgets that threw during build.
///
/// Dev builds keep Flutter's classic red error screen; store builds
/// (`APP_ENV=prod`) show a quiet recovery screen instead of leaking stack
/// traces into the UI. The failure itself is already logged via
/// [ErrorWidget.builder].
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    if (!isProd) return ErrorWidget(details.exception);
    return const ColoredBox(
      color: Color(0xFF1B1B1F),
      child: Center(child: Text('Something went wrong.')),
    );
  }
}
