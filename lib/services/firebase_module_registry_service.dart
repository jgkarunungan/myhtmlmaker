import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/activity_model.dart';
import '../models/design_config.dart';
import '../models/lesson_model.dart';
import 'firebase_config_service.dart';
import 'firebase_teacher_auth_service.dart';
import 'firestore_rest_serializer.dart';

class RegisteredModule {
  final String moduleId;
  final String teacherUid;
  final String title;
  final String subject;
  final String gradeLevel;
  final String status; // draft | published | archived
  final int activityCount;
  final int totalPoints;
  final DateTime updatedAt;
  final String? hostedUrl;

  const RegisteredModule({
    required this.moduleId,
    required this.teacherUid,
    required this.title,
    required this.subject,
    required this.gradeLevel,
    required this.status,
    required this.activityCount,
    required this.totalPoints,
    required this.updatedAt,
    this.hostedUrl,
  });

  factory RegisteredModule.fromFirestoreMap(Map<String, dynamic> data) {
    return RegisteredModule(
      moduleId: data['moduleId']?.toString() ?? '',
      teacherUid: data['teacherUid']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Untitled Module',
      subject: data['subject']?.toString() ?? 'General',
      gradeLevel: data['gradeLevel']?.toString() ?? 'Grade 11',
      status: data['status']?.toString() ?? 'draft',
      activityCount: (data['activityCount'] is num) ? (data['activityCount'] as num).toInt() : 0,
      totalPoints: (data['totalPoints'] is num) ? (data['totalPoints'] as num).toInt() : 0,
      updatedAt: data['updatedAt'] is DateTime
          ? data['updatedAt'] as DateTime
          : DateTime.now(),
      hostedUrl: data['hostedUrl']?.toString(),
    );
  }
}

/// Service managing authenticated teacher module registration via Cloud Firestore REST API.
class FirebaseModuleRegistryService {
  final http.Client _client;
  final FirebaseTeacherAuthService _authService;
  final FirebaseConfigService _firebaseConfig;

  FirebaseModuleRegistryService({
    http.Client? client,
    FirebaseTeacherAuthService? authService,
    FirebaseConfigService? firebaseConfig,
  })  : _client = client ?? http.Client(),
        _authService = authService ?? FirebaseTeacherAuthService.instance,
        _firebaseConfig = firebaseConfig ?? const FirebaseConfigService();

  String get _databaseRootUrl =>
      'https://firestore.googleapis.com/v1/projects/${_firebaseConfig.projectId}/databases/(default)/documents';

  /// Registers or updates a module in `modules/{moduleId}` and registers activity grading metadata.
  Future<void> registerModule({
    required LessonModel lesson,
    required DesignConfig designConfig,
    String status = 'draft',
  }) async {
    final session = _authService.currentSession;
    if (session == null || !session.isAuthorizedTeacher) {
      throw const TeacherAuthException('Sign in to your Firebase teacher account before registering this module.');
    }

    final idToken = await _authService.getValidIdToken();
    final moduleId = lesson.id;

    int totalPoints = 0;
    for (final act in lesson.activities) {
      totalPoints += act.points;
    }

    final Map<String, dynamic> moduleData = {
      'schemaVersion': 1,
      'moduleId': moduleId,
      'teacherUid': session.uid,
      'title': lesson.title.trim().isEmpty ? 'Self-Learning Module' : lesson.title.trim(),
      'subject': lesson.subject.trim().isEmpty ? 'General Subject' : lesson.subject.trim(),
      'gradeLevel': lesson.gradeLevel.trim().isEmpty ? 'Grade 11' : lesson.gradeLevel.trim(),
      'status': status,
      'design': {
        'profile': designConfig.visualProfile.name,
        'intensity': designConfig.designIntensity.name,
        'seed': designConfig.designSeed,
      },
      'activityCount': lesson.activities.length,
      'totalPoints': totalPoints,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };

    final fields = FirestoreRestSerializer.toFirestoreFields(moduleData);
    final String url = '$_databaseRootUrl/modules/$moduleId';

    // Check if document exists first to preserve createdAt and ensure teacherUid is immutable
    final existingResponse = await _client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (existingResponse.statusCode == 200) {
      // Module exists: ensure current teacher owns it
      final existingDecoded = jsonDecode(existingResponse.body) as Map<String, dynamic>;
      final existingFields = existingDecoded['fields'] as Map<String, dynamic>?;
      if (existingFields != null) {
        final existingTeacher = existingFields['teacherUid']?['stringValue']?.toString();
        if (existingTeacher != null && existingTeacher != session.uid) {
          throw const TeacherAuthException('Cannot modify a module owned by another teacher.');
        }
      }

      // Update existing module document using PATCH
      final updateUrl = '$url?updateMask.fieldPaths=title&updateMask.fieldPaths=subject&updateMask.fieldPaths=gradeLevel&updateMask.fieldPaths=status&updateMask.fieldPaths=design&updateMask.fieldPaths=activityCount&updateMask.fieldPaths=totalPoints&updateMask.fieldPaths=updatedAt';
      final patchRes = await _client.patch(
        Uri.parse(updateUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );

      if (patchRes.statusCode != 200) {
        throw TeacherAuthException('Failed to update module registry (${patchRes.statusCode}).');
      }
    } else {
      // Create new module document
      final createUrl = '$_databaseRootUrl/modules?documentId=$moduleId';
      final postRes = await _client.post(
        Uri.parse(createUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );

      if (postRes.statusCode != 200) {
        throw TeacherAuthException('Failed to register module in Firebase (${postRes.statusCode}).');
      }
    }

    // Register Activity Grading Metadata under modules/{moduleId}/activities/{activityId}
    await _registerActivityMetadata(
      idToken: idToken,
      moduleId: moduleId,
      activities: lesson.activities,
    );
  }

  /// Registers grading metadata for each activity in the lesson under `modules/{moduleId}/activities`.
  Future<void> _registerActivityMetadata({
    required String idToken,
    required String moduleId,
    required List<ActivityModel> activities,
  }) async {
    for (final act in activities) {
      final List<Map<String, dynamic>> questionsMeta = [];
      for (final q in act.questions) {
        questionsMeta.add({
          'questionId': q.id,
          'prompt': q.questionText,
          'points': 1,
          'answerStatus': q.answerStatus.name,
          'correctAnswer': q.correctAnswer,
        });
      }

      Map<String, dynamic>? rubricMeta;
      if (act.rubric != null) {
        rubricMeta = {
          'type': act.rubric!.type.name,
          'criteria': act.rubric!.criteriaList
              .map((c) => {
                    'criterionId': c.id,
                    'description': c.description,
                    'maxPoints': c.maxPoints,
                  })
              .toList(),
        };
      }

      final Map<String, dynamic> actData = {
        'activityId': act.id,
        'sourceOrder': act.sourceOrder,
        'title': act.title,
        'type': act.type.name,
        'instructions': act.instructions,
        'points': act.points,
        'gradingMode': act.gradingMode.name,
        'questions': questionsMeta,
        if (rubricMeta case final Map<String, dynamic> r) 'rubric': r,
      };

      final fields = FirestoreRestSerializer.toFirestoreFields(actData);
      final String actUrl = '$_databaseRootUrl/modules/$moduleId/activities?documentId=${act.id}';

      await _client.post(
        Uri.parse(actUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': fields}),
      );
    }
  }

  /// Fetches registered modules owned by the currently authenticated teacher.
  Future<List<RegisteredModule>> getRegisteredModules() async {
    final session = _authService.currentSession;
    if (session == null || !session.isAuthorizedTeacher) {
      throw const TeacherAuthException('Sign in to your Firebase teacher account to view registered modules.');
    }

    final idToken = await _authService.getValidIdToken();
    final url = '$_databaseRootUrl:runQuery';

    final queryBody = {
      'structuredQuery': {
        'from': [
          {'collectionId': 'modules'}
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'teacherUid'},
            'op': 'EQUAL',
            'value': {'stringValue': session.uid}
          }
        }
      }
    };

    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(queryBody),
    );

    if (response.statusCode != 200) {
      throw TeacherAuthException('Failed to query registered modules (${response.statusCode}).');
    }

    final List<dynamic> results = jsonDecode(response.body) as List<dynamic>;
    final List<RegisteredModule> modules = [];

    for (final item in results) {
      final docMap = item['document'] as Map<String, dynamic>?;
      if (docMap != null && docMap['fields'] != null) {
        final Map<String, dynamic> rawFields = docMap['fields'] as Map<String, dynamic>;
        final data = FirestoreRestSerializer.fromFirestoreFields(rawFields);
        modules.add(RegisteredModule.fromFirestoreMap(data));
      }
    }

    return modules;
  }

  /// Updates the status of a registered module ("draft" | "published" | "archived").
  Future<void> updateModuleStatus(String moduleId, String status) async {
    final session = _authService.currentSession;
    if (session == null || !session.isAuthorizedTeacher) {
      throw const TeacherAuthException('Sign in to update module status.');
    }

    final idToken = await _authService.getValidIdToken();
    final String url = '$_databaseRootUrl/modules/$moduleId?updateMask.fieldPaths=status&updateMask.fieldPaths=updatedAt';

    final fields = FirestoreRestSerializer.toFirestoreFields({
      'status': status,
      'updatedAt': DateTime.now(),
    });

    final response = await _client.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );

    if (response.statusCode != 200) {
      throw TeacherAuthException('Failed to update module status (${response.statusCode}).');
    }
  }
}
