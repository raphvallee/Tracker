const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

const bool isProd = appEnv == 'prod';
