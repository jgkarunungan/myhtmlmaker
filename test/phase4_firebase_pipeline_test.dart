import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhtmlmaker/config/ai_config.dart';
import 'package:myhtmlmaker/models/activity_model.dart';
import 'package:myhtmlmaker/models/design_config.dart';
import 'package:myhtmlmaker/models/lesson_model.dart';
import 'package:myhtmlmaker/services/ai_config_service.dart';
import 'package:myhtmlmaker/services/firebase_config_service.dart';
import 'package:myhtmlmaker/services/html_generator_service.dart';
import 'package:myhtmlmaker/services/gemini_analyzer.dart';
import 'package:myhtmlmaker/services/module_export_service.dart';
import 'package:myhtmlmaker/utils/module_id_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 - Firebase Architecture & Technical Corrections Tests', () {

    test('1. Gemini model is centralized and uses gemini-3.8-flash', () {
      expect(AiConfig.modelName, equals('gemini-3.8-flash'));
    });

    test('2. Gemini API key no longer persists in SharedPreferences and cleans up legacy key', () async {
      SharedPreferences.setMockInitialValues({'slm_gemini_api_key_v1': 'secret_legacy_key'});
      final prefs = await SharedPreferences.getInstance();
      final service = AiConfigService();

      await service.loadApiKey(prefsOverride: prefs);
      expect(prefs.containsKey('slm_gemini_api_key_v1'), isFalse);

      await service.saveApiKey('new_session_key', prefsOverride: prefs);
      expect(prefs.containsKey('slm_gemini_api_key_v1'), isFalse);
      expect(AiConfig.apiKey, equals('new_session_key'));
    });

    test('3. Generated module receives stable moduleId', () async {
      final generator = HtmlGeneratorService();
      final moduleId = ModuleIdGenerator.generate();
      final lesson = LessonModel(id: moduleId, title: 'Sample Lesson', subject: 'Math');

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.moduleId, equals(moduleId));
      expect(module.moduleId, startsWith('mod_'));
    });

    test('4. Regenerate Design preserves moduleId', () async {
      final generator = HtmlGeneratorService();
      final stableId = ModuleIdGenerator.generate();
      final lesson = LessonModel(id: stableId, title: 'Preserve ID Test', subject: 'Science');

      final module1 = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(designSeed: '111'),
      );
      final module2 = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(designSeed: '222'),
      );

      expect(module1.moduleId, equals(stableId));
      expect(module2.moduleId, equals(stableId));
    });

    test('5. Preview preserves moduleId', () async {
      final generator = HtmlGeneratorService();
      final stableId = ModuleIdGenerator.generate();
      final lesson = LessonModel(id: stableId, title: 'Preview ID Test', subject: 'Science');
      final exportService = ModuleExportService();

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      final result = await exportService.launchBrowserPreview(module: module);
      expect(result.isSuccess, isTrue);
      expect(module.moduleId, equals(stableId));
    });

    test('6. Export preserves moduleId', () async {
      final generator = HtmlGeneratorService();
      final stableId = ModuleIdGenerator.generate();
      final lesson = LessonModel(id: stableId, title: 'Export ID Test', subject: 'Science');

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.moduleId, equals(stableId));
      expect(module.firebaseJavaScript, contains(stableId));
    });

    test('7. Reanalysis preserves moduleId', () {
      final stableId = ModuleIdGenerator.generate();
      final lesson = LessonModel(id: stableId, title: 'Reanalyze Test', subject: 'English');

      final reanalyzed = lesson.copyWith(
        objectives: ['Objective 1'],
        sections: [],
      );

      expect(reanalyzed.id, equals(stableId));
    });

    test('8. New Module produces a different moduleId', () {
      final id1 = ModuleIdGenerator.generate();
      final id2 = ModuleIdGenerator.generate();

      expect(id1, isNot(equals(id2)));
      expect(id1, startsWith('mod_'));
      expect(id2, startsWith('mod_'));
    });

    test('9. Generated firebase.js contains shared Firebase project configuration', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(id: 'mod_123', title: 'Firebase Test', subject: 'Math');
      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);

      expect(firebaseJs, contains('online-classes-database-70d53'));
      expect(firebaseJs, contains('online-classes-database-70d53.firebaseapp.com'));
      expect(firebaseJs, contains('online-classes-database-70d53.firebasestorage.app'));
    });

    test('10. Generated firebase.js contains correct moduleId', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(id: 'mod_test_abc_890', title: 'Firebase Test', subject: 'Math');
      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_test_abc_890', lesson: lesson);

      expect(firebaseJs, contains('const MODULE_ID = "mod_test_abc_890";'));
    });

    test('11. Gemini API key never appears in generated files', () async {
      AiConfig.setApiKey('AIzaSyTEST_SECRET_KEY_12345');
      final generator = HtmlGeneratorService();
      final lesson = LessonModel(id: 'mod_123', title: 'Secret Test', subject: 'Math');

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.html, isNot(contains('AIzaSyTEST_SECRET_KEY_12345')));
      expect(module.css, isNot(contains('AIzaSyTEST_SECRET_KEY_12345')));
      expect(module.javaScript, isNot(contains('AIzaSyTEST_SECRET_KEY_12345')));
      expect(module.firebaseJavaScript, isNot(contains('AIzaSyTEST_SECRET_KEY_12345')));
    });

    test('12. Student Grade and Section remain separate in generated HTML & JS', () async {
      final generator = HtmlGeneratorService();
      final lesson = LessonModel(id: 'mod_123', title: 'Form Test', subject: 'Math');

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.html, contains('id="gradeLevel"'));
      expect(module.html, contains('id="section"'));
      expect(module.firebaseJavaScript, contains('gradeLevel: gradeLevel'));
      expect(module.firebaseJavaScript, contains('section: section'));
    });

    test('13. LRN remains optional in student form and submission schema', () async {
      final generator = HtmlGeneratorService();
      final lesson = LessonModel(id: 'mod_123', title: 'LRN Test', subject: 'Math');

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.html, contains('id="lrn"'));
      expect(module.html, isNot(contains('<input type="text" id="lrn" name="lrn" placeholder="e.g., 123456789012" required>')));
      expect(module.firebaseJavaScript, contains('lrn: lrn'));
    });

    test('14. Submission document uses activityId/questionId', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(
        id: 'mod_123',
        title: 'ID Keys Test',
        subject: 'Math',
        activities: [
          ActivityModel(
            id: 'act_math_1',
            sourceOrder: 1,
            title: 'Math Quiz',
            instructions: 'Solve questions.',
            type: ActivityType.multipleChoice,
            points: 10,
            gradingMode: GradingMode.automatic,
            questions: [
              QuestionModel(
                id: 'q_math_1_1',
                questionText: '1 + 1 = ?',
                correctAnswer: '2',
                answerStatus: AnswerStatus.provided,
              )
            ],
          )
        ],
      );

      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);
      expect(firebaseJs, contains('data-activity-id'));
      expect(firebaseJs, contains('data-question-id'));
      expect(firebaseJs, contains('act_math_1'));
      expect(firebaseJs, contains('q_math_1_1'));
    });

    test('15. Generated code uses anonymous Firebase Auth', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(id: 'mod_123', title: 'Auth Test', subject: 'Math');
      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);

      expect(firebaseJs, contains('signInAnonymously'));
      expect(firebaseJs, contains('onAuthStateChanged'));
    });

    test('16. Student submission path is modules/{moduleId}/submissions/{uid}', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(id: 'mod_12345', title: 'Path Test', subject: 'Math');
      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_12345', lesson: lesson);

      expect(firebaseJs, contains("doc(db, 'modules', MODULE_ID, 'submissions', targetUid)"));
    });

    test('17. Local file preview bypasses Firebase safely', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(id: 'mod_123', title: 'File Preview Test', subject: 'Math');
      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);

      expect(firebaseJs, contains("if (window.location.protocol === 'file:')"));
      expect(firebaseJs, contains("Preview mode — cloud saving is unavailable"));
    });

    test('18. Missing Firebase connectivity does not destroy lesson responses', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(id: 'mod_123', title: 'Offline Test', subject: 'Math');
      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);

      expect(firebaseJs, contains("Changes are waiting to be saved."));
    });

    test('19. Submit success message occurs only after confirmed save', () async {
      final generator = HtmlGeneratorService();
      final lesson = LessonModel(id: 'mod_123', title: 'Submit Test', subject: 'Math');

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.javaScript, contains("await window.ModuleFirebase.submitModule()"));
      expect(module.javaScript, contains("Your activities have been submitted successfully."));
      expect(module.javaScript, contains("Submission could not be sent. Your answers remain on this page. Please check your connection and try again."));
    });

    test('20. clientAutoScore excludes missing-answer questions', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(
        id: 'mod_123',
        title: 'Missing Answer Test',
        subject: 'Math',
        activities: [
          ActivityModel(
            id: 'act_1',
            sourceOrder: 1,
            title: 'Mixed Questions Quiz',
            instructions: 'Answer all.',
            type: ActivityType.multipleChoice,
            points: 10,
            gradingMode: GradingMode.automatic,
            questions: [
              QuestionModel(
                id: 'q_valid',
                questionText: 'What is 2+2?',
                correctAnswer: '4',
                answerStatus: AnswerStatus.provided,
              ),
              QuestionModel(
                id: 'q_missing',
                questionText: 'What is 5+5?',
                correctAnswer: '',
                answerStatus: AnswerStatus.missing,
              )
            ],
          )
        ],
      );

      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);
      expect(firebaseJs, contains("qMeta.answerStatus !== 'provided' && qMeta.answerStatus !== 'inferredHighConfidence'"));
    });

    test('21. Subjective activities are not AI-graded', () {
      const firebaseConfig = FirebaseConfigService();
      final lesson = LessonModel(
        id: 'mod_123',
        title: 'Subjective Test',
        subject: 'English',
        activities: [
          ActivityModel(
            id: 'act_essay',
            sourceOrder: 1,
            title: 'Reflection Essay',
            instructions: 'Write a summary.',
            type: ActivityType.essay,
            points: 20,
            gradingMode: GradingMode.teacher,
            questions: [],
          )
        ],
      );

      final firebaseJs = firebaseConfig.generateFirebaseJs(moduleId: 'mod_123', lesson: lesson);
      expect(firebaseJs, isNot(contains('"act_essay":{"gradingMode":"automatic"')));
    });

    test('22. Gemini Analyzer structured output schema is present and valid', () {
      expect(GeminiLessonAnalyzer.lessonAnalysisSchema['type'], equals('OBJECT'));
      expect(GeminiLessonAnalyzer.lessonAnalysisSchema['required'], contains('detectedTitle'));
    });
  });
}
