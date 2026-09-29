import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhtmlmaker/config/student_config.dart';
import 'package:myhtmlmaker/models/design_config.dart';
import 'package:myhtmlmaker/models/lesson_model.dart';
import 'package:myhtmlmaker/services/grade_section_service.dart';
import 'package:myhtmlmaker/services/html_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part A - GradeSectionService & Persistence Verification', () {
    late GradeSectionService service;

    setUp(() {
      service = GradeSectionService();
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Initial defaults apply only when no saved configuration exists', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await service.loadGradeSections();

      expect(loaded.containsKey('Grade 11'), isTrue);
      expect(loaded['Grade 11'], equals(['Angelfish', 'Faraday']));
      expect(loaded.containsKey('Grade 12'), isTrue);
      expect(loaded['Grade 12'], equals(['Newton', 'Curie', 'Archerfish']));
    });

    test('2. Settings survive persistence reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final customMap = {
        'Grade 7': ['Emerald', 'Rizal'],
        'Grade 11': ['Angelfish'],
      };

      await service.saveGradeSections(customMap, prefsOverride: prefs);

      final reloaded = await service.loadGradeSections(prefsOverride: prefs);
      expect(reloaded['Grade 7'], equals(['Emerald', 'Rizal']));
      expect(reloaded['Grade 11'], equals(['Angelfish']));
    });

    test('3. Deleted defaults do not return on reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Load initial defaults
      final initialMap = await service.loadGradeSections(prefsOverride: prefs);

      // Delete Newton from Grade 12
      initialMap['Grade 12']?.remove('Newton');
      await service.saveGradeSections(initialMap, prefsOverride: prefs);

      // Reload
      final reloadedMap = await service.loadGradeSections(prefsOverride: prefs);
      expect(reloadedMap['Grade 12'], equals(['Curie', 'Archerfish']));
      expect(reloadedMap['Grade 12']?.contains('Newton'), isFalse);
    });

    test('4. Duplicate sections are rejected case-insensitively', () {
      final map = {
        'Grade 7': ['Emerald', 'Rizal'],
      };

      final addResult = service.addSection(map, 'Grade 7', 'emerald');
      expect(addResult, isFalse);
      expect(map['Grade 7'], equals(['Emerald', 'Rizal']));

      final addUnique = service.addSection(map, 'Grade 7', 'Sapphire');
      expect(addUnique, isTrue);
      expect(map['Grade 7'], equals(['Emerald', 'Rizal', 'Sapphire']));
    });

    test('5. Grade and Section remain separate in StudentConfig', () {
      final fields = StudentConfig.studentFields;

      final gradeLevelField = fields.firstWhere((f) => f.key == 'gradeLevel');
      expect(gradeLevelField.isRequired, isTrue);
      expect(gradeLevelField.isDropdown, isTrue);

      final sectionField = fields.firstWhere((f) => f.key == 'section');
      expect(sectionField.isRequired, isTrue);
      expect(sectionField.isDropdown, isTrue);

      expect(gradeLevelField.key, isNot(equals(sectionField.key)));
    });

    test('6. Generated HTML receives separate dropdown controls and snapshot', () async {
      final generator = HtmlGeneratorService();
      const lesson = LessonModel(
        id: 'test-1',
        title: 'Photosynthesis',
        subject: 'Science',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Photosynthesis is essential for plants.',
      );

      final customSnapshot = {
        'Grade 7': ['Emerald', 'Rizal'],
        'Grade 11': ['Angelfish', 'Faraday'],
      };

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
        gradeSectionsSnapshot: customSnapshot,
      );

      final html = module.html;
      final js = module.javaScript;

      // Separate controls in HTML
      expect(html, contains('id="gradeLevel"'));
      expect(html, contains('id="section"'));
      expect(html, contains('<option value="Grade 7">Grade 7</option>'));
      expect(html, contains('<option value="Grade 11">Grade 11</option>'));

      // Embedded snapshot in JS
      expect(js, contains('GRADE_SECTIONS'));
      expect(js, contains('Emerald'));
      expect(js, contains('Rizal'));
      expect(js, contains('Angelfish'));
    });
  });
}
