import 'package:flutter_test/flutter_test.dart';
import 'package:myhtmlmaker/config/student_config.dart';
import 'package:myhtmlmaker/models/design_config.dart';
import 'package:myhtmlmaker/models/lesson_model.dart';
import 'package:myhtmlmaker/services/design_engine.dart';
import 'package:myhtmlmaker/services/html_generator_service.dart';
import 'package:myhtmlmaker/utils/html_utils.dart';
import 'package:myhtmlmaker/utils/slug_utils.dart';

void main() {
  group('Phase 2 - Centralized Student Config Verification', () {
    test('Student section options are exact and intact', () {
      expect(StudentConfig.allowedGradeAndSections, equals([
        '11 - Angelfish',
        '11 - Faraday',
        '12 - Newton',
        '12 - Curie',
        '12 - Archerfish',
      ]));
    });

    test('Required student fields exist and LRN is optional', () {
      final fields = StudentConfig.studentFields;

      final firstNameField = fields.firstWhere((f) => f.key == 'firstName');
      expect(firstNameField.isRequired, isTrue);

      final surnameField = fields.firstWhere((f) => f.key == 'surname');
      expect(surnameField.isRequired, isTrue);

      final middleNameField = fields.firstWhere((f) => f.key == 'middleName');
      expect(middleNameField.isRequired, isTrue);

      final gradeLevelField = fields.firstWhere((f) => f.key == 'gradeLevel');
      expect(gradeLevelField.isRequired, isTrue);

      final sectionField = fields.firstWhere((f) => f.key == 'section');
      expect(sectionField.isRequired, isTrue);

      final lrnField = fields.firstWhere((f) => f.key == 'lrn');
      expect(lrnField.isRequired, isFalse);
      expect(lrnField.helperText, equals('Optional but recommended'));
    });

    test('Grade & Section setup can be updated dynamically', () {
      final initialOptions = StudentConfig.allowedGradeAndSections;
      expect(initialOptions, contains('11 - Angelfish'));

      StudentConfig.updateGradeSections({
        'Grade 7': ['Emerald', 'Rizal'],
        'Grade 11': ['Angelfish', 'Faraday'],
        'Grade 12': ['Newton', 'Curie', 'Archerfish'],
      });

      expect(StudentConfig.allowedGradeAndSections, contains('7 - Emerald'));
      expect(StudentConfig.allowedGradeAndSections, contains('7 - Rizal'));

      // Restore defaults
      StudentConfig.updateGradeSections({
        'Grade 11': ['Angelfish', 'Faraday'],
        'Grade 12': ['Newton', 'Curie', 'Archerfish'],
      });
    });
  });

  group('Phase 2 - Slug Utils Verification', () {
    test('Slug generation handles spaces, punctuation, and empty input', () {
      expect(SlugUtils.generateSlug('Prudence and Human Action'), equals('prudence-and-human-action'));
      expect(SlugUtils.generateSlug('Socrates said: wisdom < knowledge & reflection > impulse.'),
          equals('socrates-said-wisdom-knowledge-reflection-impulse'));
      expect(SlugUtils.generateSlug('   Special !!! Characters ### '), equals('special-characters'));
      expect(SlugUtils.generateSlug(''), equals('module'));
    });

    test('Collision resolution generates safe sequential suffixes', () {
      final existingDirs = {'prudence', 'prudence-2'};
      final resolved = SlugUtils.resolveCollision(
        baseSlug: 'prudence',
        existsCheck: (candidate) => existingDirs.contains(candidate),
      );
      expect(resolved, equals('prudence-3'));
    });
  });

  group('Phase 2 - HTML Utility & Escaping', () {
    test('Teacher text containing HTML-like characters is properly escaped', () {
      const rawText = 'Socrates said: wisdom < knowledge & reflection > impulse.';
      final escaped = HtmlUtils.escapeHtml(rawText);

      expect(escaped, equals('Socrates said: wisdom &lt; knowledge &amp; reflection &gt; impulse.'));
      expect(escaped.contains('<'), isFalse);
      expect(escaped.contains('>'), isFalse);
    });

    test('Paragraph formatting converts lines safely', () {
      const rawText = 'First Paragraph\n\nSecond Paragraph\n- Item 1\n- Item 2';
      final formatted = HtmlUtils.formatTextToHtmlParagraphs(rawText);

      expect(formatted, contains('<p>First Paragraph</p>'));
      expect(formatted, contains('<p>Second Paragraph</p>'));
      expect(formatted, contains('<ul class="lesson-list">'));
      expect(formatted, contains('<li>Item 1</li>'));
    });
  });

  group('Phase 2 - Deterministic Design Engine', () {
    test('Same design seed produces identical design properties', () {
      const config1 = DesignConfig(
        visualProfile: VisualProfile.auto,
        designIntensity: DesignIntensity.balanced,
        designSeed: 'stable-seed-12345',
      );

      const config2 = DesignConfig(
        visualProfile: VisualProfile.auto,
        designIntensity: DesignIntensity.balanced,
        designSeed: 'stable-seed-12345',
      );

      final design1 = DesignEngine.resolve(config1);
      final design2 = DesignEngine.resolve(config2);

      expect(design1.resolvedProfile, equals(design2.resolvedProfile));
      expect(design1.primaryColor, equals(design2.primaryColor));
      expect(design1.accentColor, equals(design2.accentColor));
      expect(design1.heroStyle, equals(design2.heroStyle));
      expect(design1.cardTreatment, equals(design2.cardTreatment));
    });

    test('Different design seeds produce different design choices', () {
      const configA = DesignConfig(
        visualProfile: VisualProfile.auto,
        designIntensity: DesignIntensity.balanced,
        designSeed: 'seed-alpha-100',
      );

      const configB = DesignConfig(
        visualProfile: VisualProfile.auto,
        designIntensity: DesignIntensity.balanced,
        designSeed: 'seed-beta-9999',
      );

      final designA = DesignEngine.resolve(configA);
      final designB = DesignEngine.resolve(configB);

      // Either profile, primary color, or hero style will differ
      final isDifferent = designA.resolvedProfile != designB.resolvedProfile ||
          designA.primaryColor != designB.primaryColor ||
          designA.heroStyle != designB.heroStyle;

      expect(isDifferent, isTrue);
    });
  });

  group('Phase 2 - HTML Generator Service Pipeline', () {
    test('Generated module contains all required sections and fields', () async {
      final service = HtmlGeneratorService();
      const lesson = LessonModel(
        id: 'test-mod-001',
        title: 'Prudence in Decision Making',
        subject: 'Personal Development',
        gradeLevel: '11 - Angelfish',
        rawLessonText: 'Prudence is a cardinal virtue.\n\nSocrates said: wisdom < knowledge & reflection > impulse.',
      );

      const designConfig = DesignConfig(
        visualProfile: VisualProfile.modernAcademic,
        designIntensity: DesignIntensity.balanced,
        designSeed: 'test-seed-42',
      );

      final generatedModule = await service.generateModule(
        lesson: lesson,
        designConfig: designConfig,
      );

      expect(generatedModule.title, equals('Prudence in Decision Making'));
      expect(generatedModule.slug, equals('prudence-in-decision-making'));

      final html = generatedModule.html;

      // Title & Subject in HTML
      expect(html, contains('Prudence in Decision Making'));
      expect(html, contains('Personal Development'));
      expect(html, contains('11 - Angelfish'));

      // Student Form Fields
      expect(html, contains('id="firstName"'));
      expect(html, contains('id="surname"'));
      expect(html, contains('id="middleName"'));
      expect(html, contains('id="gradeLevel"'));
      expect(html, contains('id="section"'));
      expect(html, contains('id="lrn"'));
      expect(html, contains('Optional but recommended'));

      // Grade Options
      expect(html, contains('<option value="Grade 11">Grade 11</option>'));
      expect(html, contains('<option value="Grade 12">Grade 12</option>'));

      // Escaped Lesson Content
      expect(html, contains('Socrates said: wisdom &lt; knowledge &amp; reflection &gt; impulse.'));

      // CSS & JS Links
      expect(html, contains('<link rel="stylesheet" href="css/module.css">'));
      expect(html, contains('<script src="js/module.js"></script>'));
    });
  });
}
