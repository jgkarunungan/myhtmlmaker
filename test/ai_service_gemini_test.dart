import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myhtmlmaker/config/ai_config.dart';
import 'package:myhtmlmaker/models/activity_model.dart';
import 'package:myhtmlmaker/models/design_config.dart';
import 'package:myhtmlmaker/models/lesson_model.dart';
import 'package:myhtmlmaker/models/lesson_section.dart';
import 'package:myhtmlmaker/services/ai_service.dart';
import 'package:myhtmlmaker/services/gemini_analyzer.dart';
import 'package:myhtmlmaker/services/html_generator_service.dart';

void main() {
  group('Part B - Gemini AI Service Unit Tests', () {
    const sampleGeminiJsonResponse = '''
{
  "detectedTitle": "AI Detected Title",
  "objectives": ["Understand photosynthesis", "Describe light reactions"],
  "sections": [
    {
      "sourceOrder": 1,
      "type": "introduction",
      "title": "Introduction to Light",
      "content": "Light energy drives photosynthesis."
    }
  ],
  "activities": [
    {
      "sourceOrder": 1,
      "type": "multipleChoice",
      "title": "Light Reactions Quiz",
      "instructions": "Select the best answer.",
      "points": 15,
      "gradingMode": "automatic",
      "questions": [
        {
          "questionText": "What absorbs light?",
          "options": ["Chlorophyll", "Water", "Oxygen"],
          "correctAnswer": "Chlorophyll",
          "answerStatus": "provided"
        },
        {
          "questionText": "What is the byproduct?",
          "options": ["Carbon", "Oxygen"],
          "correctAnswer": "",
          "answerStatus": "missing"
        }
      ],
      "rubric": {
        "rubricType": "teacherProvided",
        "criteriaList": [
          {
            "description": "Accuracy",
            "maxPoints": 15
          }
        ]
      }
    }
  ],
  "designRecommendation": {
    "suggestedProfile": "Editorial",
    "mood": "Thoughtful",
    "rationale": "High text density"
  },
  "warnings": ["Section 2 has no header."]
}
''';

    late String capturedRequestBody;

    MockClient createMockClient() {
      return MockClient((request) async {
        capturedRequestBody = request.body;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': sampleGeminiJsonResponse}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });
    }

    test('1. Valid AI JSON parses into LessonModel and LessonAnalysis', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Photosynthesis Fundamentals',
        subject: 'Biology',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Original teacher text about chloroplasts and light.',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-api-key-xyz',
      );

      expect(analyzed.hasStructuredAnalysis, isTrue);
      expect(analyzed.objectives.length, equals(2));
      expect(analyzed.sections.length, equals(1));
      expect(analyzed.activities.length, equals(1));
    });

    test('2. rawLessonText remains unchanged', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const rawText = 'Original teacher raw lesson text verbatim.';
      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Title',
        subject: 'Subject',
        gradeLevel: 'Grade 11',
        rawLessonText: rawText,
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      expect(analyzed.rawLessonText, equals(rawText));
    });

    test('3. Teacher title has priority over AI detected title', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Teacher Specified Title',
        subject: 'Science',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Some lesson text.',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      expect(analyzed.title, equals('Teacher Specified Title'));
    });

    test('4. Teacher point values survive in ActivityModel', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Title',
        subject: 'Subject',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Lesson text',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      expect(analyzed.activities.first.points, equals(15));
    });

    test('5 & 6. Provided answer remains provided and missing answer remains missing', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Title',
        subject: 'Subject',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Lesson text',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      final questions = analyzed.activities.first.questions;
      expect(questions[0].answerStatus, equals(AnswerStatus.provided));
      expect(questions[1].answerStatus, equals(AnswerStatus.missing));
    });

    test('7. Missing answer prevents automatic grading mode', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Title',
        subject: 'Subject',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Lesson text',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      // Even though JSON returned "automatic", question 2 was "missing", so it downgraded to "teacher"
      expect(analyzed.activities.first.gradingMode, equals(GradingMode.teacher));
    });

    test('8 & 9. Rubric type preservation (teacherProvided vs aiSuggested)', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Title',
        subject: 'Subject',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Lesson text',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      expect(analyzed.activities.first.rubric?.type, equals(RubricType.teacherProvided));
    });

    test('10 & 11. Activity IDs and Question IDs are generated locally', () async {
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Title',
        subject: 'Subject',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Lesson text',
      );

      final analyzed = await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key',
      );

      final act = analyzed.activities.first;
      expect(act.id, startsWith('act_'));
      expect(act.questions.first.id, startsWith('q_'));
    });

    test('12. Student names, sections, LRN are NOT present in Gemini request payload', () async {
      capturedRequestBody = '';
      final mockClient = createMockClient();
      final analyzer = GeminiLessonAnalyzer(client: mockClient);
      final aiService = AIService(geminiAnalyzer: analyzer);

      const lessonInput = LessonModel(
        id: 'mod-123',
        title: 'Cellular Respiration',
        subject: 'Biology',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Glucose breaking down into ATP.',
      );

      await aiService.analyzeLesson(
        currentLesson: lessonInput,
        apiKeyOverride: 'test-key-123',
      );

      expect(capturedRequestBody.contains('firstName'), isFalse);
      expect(capturedRequestBody.contains('surname'), isFalse);
      expect(capturedRequestBody.contains('lrn'), isFalse);
      expect(capturedRequestBody.contains('Angelfish'), isFalse);
    });

    test('13. API Key never appears in generated module HTML output', () async {
      final generator = HtmlGeneratorService();
      const lesson = LessonModel(
        id: 'test-mod-001',
        title: 'Cellular Respiration',
        subject: 'Biology',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Glucose breaking down into ATP.',
      );

      const secretKey = 'AIzaSySecretApiKeyDoNotExpose12345';
      AiConfig.setApiKey(secretKey);

      final module = await generator.generateModule(
        lesson: lesson,
        designConfig: const DesignConfig(),
      );

      expect(module.html.contains(secretKey), isFalse);
      expect(module.css.contains(secretKey), isFalse);
      expect(module.javaScript.contains(secretKey), isFalse);
    });

    test('14 & 15. Structured lesson renders successfully and raw-text fallback still works', () async {
      final generator = HtmlGeneratorService();

      // Case A: Structured lesson
      const structuredLesson = LessonModel(
        id: 'mod-1',
        title: 'Cell Biology',
        subject: 'Biology',
        gradeLevel: 'Grade 11',
        rawLessonText: 'Raw text fallback',
        objectives: ['Identify organelles', 'Understand membrane transport'],
        sections: [
          LessonSection(id: 'sec-1', title: 'Mitochondria', type: SectionType.discussion, content: 'Powerhouse of cell.')
        ],
        activities: [
          ActivityModel(id: 'act-1', title: 'Cell Quiz', instructions: 'Answer questions', type: ActivityType.multipleChoice)
        ],
      );

      final moduleA = await generator.generateModule(
        lesson: structuredLesson,
        designConfig: const DesignConfig(),
      );

      expect(moduleA.html, contains('Identify organelles'));
      expect(moduleA.html, contains('Mitochondria'));
      expect(moduleA.html, contains('Cell Quiz'));

      // Case B: Raw text fallback
      const rawLesson = LessonModel(
        id: 'mod-2',
        title: 'Physics 101',
        subject: 'Physics',
        gradeLevel: 'Grade 12',
        rawLessonText: 'Newton second law: F = ma.',
      );

      final moduleB = await generator.generateModule(
        lesson: rawLesson,
        designConfig: const DesignConfig(),
      );

      expect(moduleB.html, contains('Newton second law: F = ma.'));
    });
  });
}
