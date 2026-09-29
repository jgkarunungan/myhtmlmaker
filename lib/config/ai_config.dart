import 'dart:io';

/// Centralized AI Configuration
class AiConfig {
  static const String providerName = 'Gemini';
  static const String modelName = 'gemini-3.8-flash';
  static const Duration requestTimeout = Duration(seconds: 35);
  static const String geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String _apiKey = '';

  /// Returns the configured API key. Checks memory first, then environment variable.
  static String get apiKey {
    if (_apiKey.isNotEmpty) {
      return _apiKey;
    }
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    try {
      final sysEnv = Platform.environment['GEMINI_API_KEY'];
      if (sysEnv != null && sysEnv.isNotEmpty) {
        return sysEnv;
      }
    } catch (_) {}
    return '';
  }

  static void setApiKey(String key) {
    _apiKey = key.trim();
  }

  static bool get hasApiKey => apiKey.isNotEmpty;
}
