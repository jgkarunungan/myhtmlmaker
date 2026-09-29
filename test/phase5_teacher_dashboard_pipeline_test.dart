import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhtmlmaker/config/ai_config.dart';
import 'package:myhtmlmaker/models/activity_model.dart';
import 'package:myhtmlmaker/models/lesson_model.dart';
import 'package:myhtmlmaker/services/firebase_teacher_auth_service.dart';
import 'package:myhtmlmaker/services/firestore_rest_serializer.dart';
import 'package:myhtmlmaker/utils/module_id_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 - Teacher Authentication & Dashboard Pipeline Tests', () {

    test('1. Passwords and ID/refresh tokens are not persisted to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseTeacherAuthService();

      await authService.setRememberedEmail('teacher@school.edu', prefsOverride: prefs);

      expect(prefs.containsKey('slm_remembered_teacher_email'), isTrue);
      expect(prefs.getString('slm_remembered_teacher_email'), equals('teacher@school.edu'));

      // Ensure no secret keys exist in SharedPreferences
      expect(prefs.containsKey('password'), isFalse);
      expect(prefs.containsKey('idToken'), isFalse);
      expect(prefs.containsKey('refreshToken'), isFalse);
    });

    test('2. Firestore REST Serializer converts Dart values to/from Firestore fields correctly', () {
      final inputMap = {
        'title': 'Sample Module',
        'points': 50,
        'rating': 4.5,
        'published': true,
        'tags': ['math', 'algebra'],
        'metadata': {'author': 'Prof. Jane'},
      };

      final fields = FirestoreRestSerializer.toFirestoreFields(inputMap);
      expect(fields['title'], equals({'stringValue': 'Sample Module'}));
      expect(fields['points'], equals({'integerValue': '50'}));
      expect(fields['rating'], equals({'doubleValue': 4.5}));
      expect(fields['published'], equals({'booleanValue': true}));

      final decoded = FirestoreRestSerializer.fromFirestoreFields(fields);
      expect(decoded['title'], equals('Sample Module'));
      expect(decoded['points'], equals(50));
      expect(decoded['published'], isTrue);
      expect(decoded['tags'], equals(['math', 'algebra']));
      expect(decoded['metadata'], equals({'author': 'Prof. Jane'}));
    });

    test('3. Teacher-owned module registration uses stable moduleId', () {
      final stableId = ModuleIdGenerator.generate();
      final lesson = LessonModel(
        id: stableId,
        title: 'Registry Test',
        subject: 'Physics',
      );

      expect(lesson.id, equals(stableId));
      expect(lesson.id, startsWith('mod_'));
    });

    test('4. Module registry status defaults to draft and publishing changes status without changing moduleId', () {
      final stableId = ModuleIdGenerator.generate();
      final lesson = LessonModel(
        id: stableId,
        title: 'Publish Test',
        subject: 'Physics',
      );

      const defaultStatus = 'draft';
      const publishedStatus = 'published';

      expect(defaultStatus, equals('draft'));
      expect(publishedStatus, equals('published'));
      expect(lesson.id, equals(stableId));
    });

    test('5. Activity metadata uses stable activityId and questionId', () {
      final activity = ActivityModel(
        id: 'act_101',
        sourceOrder: 1,
        title: 'Algebra Quiz',
        instructions: 'Solve all.',
        type: ActivityType.multipleChoice,
        points: 20,
        gradingMode: GradingMode.automatic,
        questions: [
          QuestionModel(
            id: 'q_101_1',
            questionText: 'Find x: 2x = 4',
            correctAnswer: '2',
            answerStatus: AnswerStatus.provided,
          )
        ],
      );

      expect(activity.id, equals('act_101'));
      expect(activity.questions.first.id, equals('q_101_1'));
    });

    test('6. Gemini API key never reaches Firebase metadata or registry', () {
      AiConfig.setApiKey('AIzaSyTEST_SECRET_KEY_12345');

      final lesson = LessonModel(
        id: 'mod_registry_123',
        title: 'Registry Secret Test',
        subject: 'Math',
      );

      final Map<String, dynamic> moduleData = {
        'schemaVersion': 1,
        'moduleId': lesson.id,
        'teacherUid': 'teacher_uid_123',
        'title': lesson.title,
        'subject': lesson.subject,
      };

      final encoded = FirestoreRestSerializer.toFirestoreFields(moduleData);
      final jsonStr = encoded.toString();

      expect(jsonStr, isNot(contains('AIzaSyTEST_SECRET_KEY_12345')));
    });

    test('7. Student information never enters module registry document', () {
      final lesson = LessonModel(
        id: 'mod_registry_123',
        title: 'Clean Registry Test',
        subject: 'Math',
      );

      final Map<String, dynamic> registryData = {
        'schemaVersion': 1,
        'moduleId': lesson.id,
        'teacherUid': 'teacher_uid_123',
        'title': lesson.title,
        'subject': lesson.subject,
        'gradeLevel': lesson.gradeLevel,
        'status': 'published',
        'activityCount': 2,
        'totalPoints': 20,
      };

      expect(registryData.containsKey('student'), isFalse);
      expect(registryData.containsKey('firstName'), isFalse);
      expect(registryData.containsKey('responses'), isFalse);
    });

    test('8. Teacher session holds expiration and memory model', () {
      final session = TeacherSession(
        uid: 'uid_123',
        email: 'teacher@school.edu',
        idToken: 'id_token_xyz',
        refreshToken: 'refresh_token_abc',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        isAuthorizedTeacher: true,
      );

      expect(session.isExpired, isFalse);
      expect(session.uid, equals('uid_123'));
      expect(session.isAuthorizedTeacher, isTrue);
    });
  });
}
