import 'package:shared_preferences/shared_preferences.dart';
import '../config/ai_config.dart';

/// Manages session memory storage of AI configuration (e.g. Gemini API Key).
///
/// Plaintext API secrets are NOT persisted to SharedPreferences for security.
/// Migration automatically removes any legacy plaintext keys stored previously.
class AiConfigService {
  static const String _legacyKeyStorageKey = 'slm_gemini_api_key_v1';

  /// Performs cleanup of legacy SharedPreferences API keys and returns current memory/env API key.
  Future<String> loadApiKey({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacyKeyStorageKey)) {
      await prefs.remove(_legacyKeyStorageKey);
    }
    return AiConfig.apiKey;
  }

  /// Sets the API key in session memory and purges any legacy plaintext SharedPreferences key.
  Future<void> saveApiKey(String apiKey, {SharedPreferences? prefsOverride}) async {
    final trimmed = apiKey.trim();
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacyKeyStorageKey)) {
      await prefs.remove(_legacyKeyStorageKey);
    }
    AiConfig.setApiKey(trimmed);
  }
}
