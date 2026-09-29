import '../config/ai_config.dart';
import '../models/lesson_analysis.dart';
import '../models/lesson_model.dart';
import 'gemini_analyzer.dart';

/// Facade boundary isolating AI operations from Flutter UI widgets.
class AIService {
  final GeminiLessonAnalyzer _geminiAnalyzer;

  AIService({GeminiLessonAnalyzer? geminiAnalyzer})
      : _geminiAnalyzer = geminiAnalyzer ?? GeminiLessonAnalyzer();

  /// Returns true if an API key is available.
  bool get hasApiKey => AiConfig.hasApiKey;

  /// Tests connection to the Gemini API with a minimal request.
  Future<bool> testConnection({String? apiKeyOverride}) async {
    return await _geminiAnalyzer.testConnection(apiKeyOverride: apiKeyOverride);
  }

  /// Performs lesson analysis on teacher's lesson text using Gemini.
  ///
  /// PRIVACY RULE: Never sends student names, middle names, surnames, LRNs,
  /// student section lists, or student responses.
  Future<LessonModel> analyzeLesson({
    required LessonModel currentLesson,
    String? apiKeyOverride,
  }) async {
    final LessonAnalysis analysis = await _geminiAnalyzer.analyzeLesson(
      title: currentLesson.title,
      subject: currentLesson.subject,
      gradeLevel: currentLesson.gradeLevel,
      rawLessonText: currentLesson.rawLessonText,
      apiKeyOverride: apiKeyOverride,
    );

    // Teacher-provided title takes priority; fallback to detected title if empty
    final String finalTitle = currentLesson.title.trim().isEmpty && analysis.detectedTitle.isNotEmpty
        ? analysis.detectedTitle
        : currentLesson.title;

    return currentLesson.copyWith(
      title: finalTitle,
      objectives: analysis.objectives,
      sections: analysis.sections,
      activities: analysis.activities,
      analysis: analysis,
    );
  }
}
