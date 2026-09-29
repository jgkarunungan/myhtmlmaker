import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing persistence and business logic for Grade & Section setup.
class GradeSectionService {
  static const String _storageKey = 'slm_grade_sections_v1';

  static Map<String, List<String>> get defaultGradeSections => {
        'Grade 11': ['Angelfish', 'Faraday'],
        'Grade 12': ['Newton', 'Curie', 'Archerfish'],
      };

  /// Loads Grade and Section configuration from persistent storage.
  /// Defaults apply ONLY on first run when no saved configuration exists.
  Future<Map<String, List<String>>> loadGradeSections({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      // First run: apply initial defaults and save
      final defaults = _copyMap(defaultGradeSections);
      await saveGradeSections(defaults, prefsOverride: prefs);
      return defaults;
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final Map<String, List<String>> result = {};
      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = value.map((e) => e.toString()).toList();
        } else {
          result[key] = [];
        }
      });
      return result;
    } catch (_) {
      return _copyMap(defaultGradeSections);
    }
  }

  /// Saves the Grade & Section configuration to SharedPreferences.
  Future<void> saveGradeSections(
    Map<String, List<String>> gradeSections, {
    SharedPreferences? prefsOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final jsonString = jsonEncode(gradeSections);
    await prefs.setString(_storageKey, jsonString);
  }

  /// Adds a section to [gradeLevel]. Rejects case-insensitive duplicates.
  bool addSection(Map<String, List<String>> map, String gradeLevel, String sectionName) {
    final trimmed = sectionName.trim();
    if (trimmed.isEmpty) return false;

    final list = map.putIfAbsent(gradeLevel, () => []);
    final exists = list.any((s) => s.trim().toLowerCase() == trimmed.toLowerCase());
    if (exists) {
      return false; // Case-insensitive duplicate rejected
    }

    list.add(trimmed);
    return true;
  }

  /// Deletes a section at [index] for [gradeLevel].
  bool deleteSection(Map<String, List<String>> map, String gradeLevel, int index) {
    final list = map[gradeLevel];
    if (list != null && index >= 0 && index < list.length) {
      list.removeAt(index);
      return true;
    }
    return false;
  }

  /// Edits a section at [index] for [gradeLevel]. Rejects case-insensitive duplicates.
  bool editSection(Map<String, List<String>> map, String gradeLevel, int index, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    final list = map[gradeLevel];
    if (list != null && index >= 0 && index < list.length) {
      final existsOther = list.asMap().entries.any(
            (e) => e.key != index && e.value.trim().toLowerCase() == trimmed.toLowerCase(),
          );
      if (existsOther) {
        return false;
      }
      list[index] = trimmed;
      return true;
    }
    return false;
  }

  Map<String, List<String>> _copyMap(Map<String, List<String>> original) {
    return Map.from(original.map((k, v) => MapEntry(k, List<String>.from(v))));
  }
}
