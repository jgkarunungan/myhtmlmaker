import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../models/activity_model.dart';
import '../models/design_config.dart';
import '../models/lesson_analysis.dart';
import '../models/lesson_section.dart';

class GeminiAnalyzerException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiAnalyzerException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Direct client interacting with Gemini Developer REST API using structured JSON output.
class GeminiLessonAnalyzer {
  final http.Client _client;

  GeminiLessonAnalyzer({http.Client? client}) : _client = client ?? http.Client();

  /// Canonical JSON Schema definition for structured lesson analysis output from Gemini.
  static final Map<String, dynamic> lessonAnalysisSchema = {
    'type': 'OBJECT',
    'properties': {
      'detectedTitle': {'type': 'STRING'},
      'objectives': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'}
      },
      'sections': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'sourceOrder': {'type': 'INTEGER'},
            'type': {'type': 'STRING'},
            'title': {'type': 'STRING'},
            'content': {'type': 'STRING'}
          },
          'required': ['sourceOrder', 'type', 'title', 'content']
        }
      },
      'activities': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'sourceOrder': {'type': 'INTEGER'},
            'type': {'type': 'STRING'},
            'title': {'type': 'STRING'},
            'instructions': {'type': 'STRING'},
            'points': {'type': 'INTEGER'},
            'gradingMode': {'type': 'STRING'},
            'questions': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'questionText': {'type': 'STRING'},
                  'options': {
                    'type': 'ARRAY',
                    'items': {'type': 'STRING'}
                  },
                  'correctAnswer': {'type': 'STRING'},
                  'answerStatus': {'type': 'STRING'}
                },
                'required': ['questionText', 'answerStatus']
              }
            },
            'rubric': {
              'type': 'OBJECT',
              'properties': {
                'rubricType': {'type': 'STRING'},
                'criteriaList': {
                  'type': 'ARRAY',
                  'items': {
                    'type': 'OBJECT',
                    'properties': {
                      'description': {'type': 'STRING'},
                      'maxPoints': {'type': 'INTEGER'}
                    },
                    'required': ['description', 'maxPoints']
                  }
                }
              }
            }
          },
          'required': ['sourceOrder', 'type', 'title', 'instructions', 'points', 'gradingMode']
        }
      },
      'designRecommendation': {
        'type': 'OBJECT',
        'properties': {
          'suggestedProfile': {'type': 'STRING'},
          'mood': {'type': 'STRING'},
          'rationale': {'type': 'STRING'}
        }
      },
      'warnings': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'}
      }
    },
    'required': ['detectedTitle', 'objectives', 'sections', 'activities', 'designRecommendation']
  };

  /// Tests the connection to Gemini Developer API with a minimal request.
  Future<bool> testConnection({String? apiKeyOverride}) async {
    final key = apiKeyOverride ?? AiConfig.apiKey;
    if (key.isEmpty) {
      throw const GeminiAnalyzerException('API Key is missing. Please configure your key in Settings.');
    }

    final url = Uri.parse('${AiConfig.geminiEndpoint}/${AiConfig.modelName}:generateContent?key=$key');

    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'Ping'}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 5,
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final error = body['error']?['message'] ?? 'API HTTP error ${response.statusCode}';
        throw GeminiAnalyzerException('Connection test failed: $error', statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw const GeminiAnalyzerException('Connection test timed out.');
    } catch (e) {
      if (e is GeminiAnalyzerException) rethrow;
      throw GeminiAnalyzerException('Failed to connect to Gemini API: ${e.toString()}');
    }
  }

  /// Sends lesson text to Gemini and parses the response into [LessonAnalysis].
  Future<LessonAnalysis> analyzeLesson({
    required String title,
    required String subject,
    required String gradeLevel,
    required String rawLessonText,
    String? apiKeyOverride,
  }) async {
    final key = apiKeyOverride ?? AiConfig.apiKey;
    if (key.isEmpty) {
      throw const GeminiAnalyzerException('Gemini API Key is missing. Please enter your API key in Settings.');
    }

    final prompt = _buildSystemPrompt(
      title: title,
      subject: subject,
      gradeLevel: gradeLevel,
      rawLessonText: rawLessonText,
    );

    final url = Uri.parse('${AiConfig.geminiEndpoint}/${AiConfig.modelName}:generateContent?key=$key');

    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseFormat': lessonAnalysisSchema,
        'responseSchema': lessonAnalysisSchema,
        'temperature': 0.2,
      }
    });

    http.Response response;
    try {
      response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(AiConfig.requestTimeout);

      // Handle transient server errors (500/503) with ONE retry
      if (response.statusCode >= 500) {
        await Future.delayed(const Duration(milliseconds: 1000));
        response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(AiConfig.requestTimeout);
      }
    } on TimeoutException {
      throw const GeminiAnalyzerException('The Gemini request timed out. Please check your internet connection.');
    } catch (e) {
      if (e is GeminiAnalyzerException) rethrow;
      throw GeminiAnalyzerException('Network error while reaching Gemini API: ${e.toString()}');
    }

    if (response.statusCode != 200) {
      String msg = 'Gemini service error (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded['error']?['message'] != null) {
          msg = decoded['error']['message'];
        }
      } catch (_) {}
      throw GeminiAnalyzerException(msg, statusCode: response.statusCode);
    }

    try {
      final decodedResponse = jsonDecode(response.body);
      final candidates = decodedResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiAnalyzerException('Received empty response candidates from Gemini.');
      }

      final parts = candidates.first['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw const GeminiAnalyzerException('Received empty text payload from Gemini.');
      }

      final String rawJsonText = parts.first['text'] ?? '';
      final Map<String, dynamic> jsonMap = jsonDecode(rawJsonText);

      return _parseJsonAnalysis(jsonMap);
    } catch (e) {
      if (e is GeminiAnalyzerException) rethrow;
      throw GeminiAnalyzerException('Failed to parse Gemini analysis output: ${e.toString()}');
    }
  }

  String _buildSystemPrompt({
    required String title,
    required String subject,
    required String gradeLevel,
    required String rawLessonText,
  }) {
    return '''
You are an expert curriculum design assistant for a Self-Learning Module Studio.
Analyze the provided teacher's lesson content and extract structured data matching the JSON schema below.

IMPORTANT RULES:
1. PRIVACY: Do NOT look for or invent any student names, personal information, or student responses.
2. PRESERVATION: Retain the teacher's original concepts and tone. Do not rewrite unless clarifying structure.
3. ANSWER SAFETY:
   - "provided": Correct answer is explicitly stated in the teacher's lesson text.
   - "inferredHighConfidence": Correct answer is unmistakably supported by the lesson text.
   - "missing": Answer is not stated or uncertain. DO NOT invent fake answers.
   - Objective questions with "missing" answers must NOT use automatic grading.
4. RUBRICS:
   - If teacher provided a rubric, mark rubricType as "teacherProvided".
   - If no rubric exists, suggest criteria with rubricType as "aiSuggested".
   - Sum of criteria maxPoints MUST equal activity total points.
5. DESIGN RECOMMENDATION: Recommend ONE visual profile: "Modern Academic", "Editorial", "Reflective Journal", or "Interactive Cards".

JSON SCHEMA TO RETURN:
{
  "detectedTitle": "string",
  "objectives": ["string"],
  "sections": [
    {
      "sourceOrder": 1,
      "type": "introduction|objectives|discussion|example|quote|activity|assessment|reflection|summary|other",
      "title": "string",
      "content": "string"
    }
  ],
  "activities": [
    {
      "sourceOrder": 1,
      "type": "multipleChoice|trueFalse|identification|matching|shortAnswer|essay|reflection|situationAnalysis|caseStudy|performanceTask|other",
      "title": "string",
      "instructions": "string",
      "points": 10,
      "gradingMode": "automatic|teacher|aiAssistedTeacher",
      "questions": [
        {
          "questionText": "string",
          "options": ["string"],
          "correctAnswer": "string",
          "answerStatus": "provided|inferredHighConfidence|missing"
        }
      ],
      "rubric": {
        "rubricType": "teacherProvided|aiSuggested",
        "criteriaList": [
          {
            "description": "string",
            "maxPoints": 5
          }
        ]
      }
    }
  ],
  "designRecommendation": {
    "suggestedProfile": "Modern Academic|Editorial|Reflective Journal|Interactive Cards",
    "mood": "string",
    "rationale": "string"
  },
  "warnings": ["string"]
}

LESSON METADATA:
Title: $title
Subject: $subject
Grade Level: $gradeLevel

TEACHER LESSON CONTENT:
$rawLessonText
''';
  }

  LessonAnalysis _parseJsonAnalysis(Map<String, dynamic> json) {
    if (json.isEmpty && !json.containsKey('detectedTitle')) {
      throw const GeminiAnalyzerException('Invalid or empty lesson analysis JSON returned from Gemini.');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final detectedTitle = json['detectedTitle']?.toString() ?? '';

    // Objectives
    final objectivesList = (json['objectives'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    // Sections
    final List<LessonSection> sections = [];
    final rawSections = json['sections'] as List?;
    if (rawSections != null) {
      for (int i = 0; i < rawSections.length; i++) {
        final sMap = rawSections[i] as Map<String, dynamic>?;
        if (sMap == null) continue;

        final typeStr = sMap['type']?.toString() ?? 'other';
        final secType = SectionType.fromString(typeStr);
        final title = sMap['title']?.toString() ?? '';
        final content = sMap['content']?.toString() ?? '';

        sections.add(LessonSection(
          id: 'sec_${nowMs}_$i',
          sourceOrder: sMap['sourceOrder'] is int ? sMap['sourceOrder'] : i + 1,
          title: title,
          type: secType,
          content: content,
        ));
      }
    }

    // Activities & Questions
    final List<ActivityModel> activities = [];
    final rawActivities = json['activities'] as List?;
    if (rawActivities != null) {
      for (int i = 0; i < rawActivities.length; i++) {
        final aMap = rawActivities[i] as Map<String, dynamic>?;
        if (aMap == null) continue;

        final actType = ActivityType.fromString(aMap['type']?.toString() ?? 'other');
        final title = aMap['title']?.toString() ?? 'Activity ${i + 1}';
        final instructions = aMap['instructions']?.toString() ?? '';
        final points = (aMap['points'] is num) ? (aMap['points'] as num).toInt() : 10;
        var gradingMode = GradingMode.fromString(aMap['gradingMode']?.toString() ?? 'teacher');

        // Questions
        final List<QuestionModel> questions = [];
        final rawQuestions = aMap['questions'] as List?;
        if (rawQuestions != null) {
          for (int qI = 0; qI < rawQuestions.length; qI++) {
            final qMap = rawQuestions[qI] as Map<String, dynamic>?;
            if (qMap == null) continue;

            final qText = qMap['questionText']?.toString() ?? '';
            final options = (qMap['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final corrAns = qMap['correctAnswer']?.toString() ?? '';
            final statusStr = qMap['answerStatus']?.toString() ?? 'missing';
            final answerStatus = AnswerStatus.fromString(statusStr);

            questions.add(QuestionModel(
              id: 'q_${nowMs}_${i}_$qI',
              questionText: qText,
              options: options,
              correctAnswer: corrAns,
              answerStatus: answerStatus,
            ));
          }
        }

        // Answer Safety Rule: Missing answers CANNOT use automatic grading
        final hasMissingAnswer = questions.any((q) => q.answerStatus == AnswerStatus.missing);
        if (hasMissingAnswer && gradingMode == GradingMode.automatic) {
          gradingMode = GradingMode.teacher;
        }

        // Rubric
        RubricModel? rubric;
        final rMap = aMap['rubric'] as Map<String, dynamic>?;
        if (rMap != null) {
          final rType = RubricType.fromString(rMap['rubricType']?.toString() ?? 'aiSuggested');
          final rawCriteria = rMap['criteriaList'] as List?;
          final List<RubricCriteria> criteriaList = [];
          if (rawCriteria != null) {
            for (int cI = 0; cI < rawCriteria.length; cI++) {
              final cMap = rawCriteria[cI] as Map<String, dynamic>?;
              if (cMap == null) continue;
              criteriaList.add(RubricCriteria(
                id: 'crit_${nowMs}_${i}_$cI',
                description: cMap['description']?.toString() ?? 'Criterion ${cI + 1}',
                maxPoints: (cMap['maxPoints'] is num) ? (cMap['maxPoints'] as num).toInt() : 5,
              ));
            }
          }
          rubric = RubricModel(
            title: '$title Rubric',
            type: rType,
            criteriaList: criteriaList,
          );
        }

        activities.add(ActivityModel(
          id: 'act_${nowMs}_$i',
          sourceOrder: aMap['sourceOrder'] is int ? aMap['sourceOrder'] : i + 1,
          title: title,
          instructions: instructions,
          type: actType,
          points: points,
          gradingMode: gradingMode,
          questions: questions,
          rubric: rubric,
        ));
      }
    }

    // Design Recommendation
    DesignRecommendation recommendation = const DesignRecommendation();
    final dMap = json['designRecommendation'] as Map<String, dynamic>?;
    if (dMap != null) {
      final profStr = dMap['suggestedProfile']?.toString() ?? 'Auto';
      VisualProfile profile = VisualProfile.auto;
      for (final p in VisualProfile.values) {
        if (p.label.toLowerCase() == profStr.toLowerCase()) {
          profile = p;
          break;
        }
      }
      recommendation = DesignRecommendation(
        suggestedProfile: profile,
        mood: dMap['mood']?.toString() ?? '',
        rationale: dMap['rationale']?.toString() ?? '',
      );
    }

    // Warnings
    final warnings = (json['warnings'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return LessonAnalysis(
      status: AnalysisStatus.success,
      detectedTitle: detectedTitle,
      objectives: objectivesList,
      sections: sections,
      activities: activities,
      recommendation: recommendation,
      warnings: warnings,
      analyzedAt: DateTime.now(),
    );
  }
}
