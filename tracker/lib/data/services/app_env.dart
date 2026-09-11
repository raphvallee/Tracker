/// Compile-time environment, injected via `--dart-define`:
///
/// ```
/// flutter build appbundle --release --dart-define=APP_ENV=prod
/// ```
///
/// Defaults to `dev` so local and test builds never accidentally gate
/// development affordances off (PRODUCTION_READINESS.md Phase 1).
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

/// True for production (store) builds. Dev-only affordances - verbose
/// logging and rich error surfaces - key off this flag.
const bool isProd = appEnv == 'prod';
