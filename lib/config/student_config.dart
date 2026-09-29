/// Centralized Student Configuration Schema
///
/// Contains the student information schema and allowed grade/section values.
/// This configuration is used by both the generator app and student web modules.
class StudentConfig {
  static Map<String, List<String>> _gradeSectionsMap = {
    'Grade 11': ['Angelfish', 'Faraday'],
    'Grade 12': ['Newton', 'Curie', 'Archerfish'],
  };

  static Map<String, List<String>> get gradeSectionsMap =>
      Map.unmodifiable(_gradeSectionsMap.map((k, v) => MapEntry(k, List<String>.from(v))));

  static List<String> get allowedGradeLevels {
    final levels = _gradeSectionsMap.keys.toList();
    if (levels.isEmpty) {
      return ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];
    }
    return levels;
  }

  static List<String> get allowedGradeAndSections {
    final List<String> list = [];
    for (final entry in _gradeSectionsMap.entries) {
      final gradeNum = entry.key.replaceAll(RegExp(r'[^\d]'), '');
      final prefix = gradeNum.isNotEmpty ? gradeNum : entry.key;
      for (final section in entry.value) {
        list.add('$prefix - $section');
      }
    }
    return list.isNotEmpty
        ? list
        : const [
            '11 - Angelfish',
            '11 - Faraday',
            '12 - Newton',
            '12 - Curie',
            '12 - Archerfish',
          ];
  }

  static void updateGradeSections(Map<String, List<String>> newMap) {
    _gradeSectionsMap = Map.from(newMap.map((k, v) => MapEntry(k, List<String>.from(v))));
  }

  static const String lrnNote = 'Optional but recommended';

  static const List<StudentField> studentFields = [
    StudentField(key: 'firstName', label: 'First Name', isRequired: true),
    StudentField(key: 'surname', label: 'Surname', isRequired: true),
    StudentField(key: 'middleName', label: 'Middle Name', isRequired: true),
    StudentField(key: 'gradeLevel', label: 'Grade Level', isRequired: true, isDropdown: true),
    StudentField(key: 'section', label: 'Section', isRequired: true, isDropdown: true),
    StudentField(key: 'lrn', label: 'LRN', isRequired: false, helperText: lrnNote),
  ];
}

class StudentField {
  final String key;
  final String label;
  final bool isRequired;
  final bool isDropdown;
  final String? helperText;

  const StudentField({
    required this.key,
    required this.label,
    required this.isRequired,
    this.isDropdown = false,
    this.helperText,
  });
}
