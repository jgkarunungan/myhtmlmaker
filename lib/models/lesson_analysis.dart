import 'activity_model.dart';
import 'design_config.dart';
import 'lesson_section.dart';

enum AnalysisStatus {
  notAnalyzed,
  analyzing,
  success,
  outdated,
  error,
}

class DesignRecommendation {
  final VisualProfile suggestedProfile;
  final String mood;
  final String rationale;

  const DesignRecommendation({
    this.suggestedProfile = VisualProfile.auto,
    this.mood = '',
    this.rationale = '',
  });

  DesignRecommendation copyWith({
    VisualProfile? suggestedProfile,
    String? mood,
    String? rationale,
  }) {
    return DesignRecommendation(
      suggestedProfile: suggestedProfile ?? this.suggestedProfile,
      mood: mood ?? this.mood,
      rationale: rationale ?? this.rationale,
    );
  }
}

class LessonAnalysis {
  final AnalysisStatus status;
  final String detectedTitle;
  final List<String> objectives;
  final List<LessonSection> sections;
  final List<ActivityModel> activities;
  final DesignRecommendation recommendation;
  final List<String> warnings;
  final String? errorMessage;
  final DateTime? analyzedAt;

  const LessonAnalysis({
    this.status = AnalysisStatus.notAnalyzed,
    this.detectedTitle = '',
    this.objectives = const [],
    this.sections = const [],
    this.activities = const [],
    this.recommendation = const DesignRecommendation(),
    this.warnings = const [],
    this.errorMessage,
    this.analyzedAt,
  });

  bool get isAnalyzed => status == AnalysisStatus.success || status == AnalysisStatus.outdated;

  int get automaticCount => activities
      .where((a) => a.gradingMode == GradingMode.automatic)
      .length;

  int get teacherScoredCount => activities
      .where((a) => a.gradingMode != GradingMode.automatic)
      .length;

  LessonAnalysis copyWith({
    AnalysisStatus? status,
    String? detectedTitle,
    List<String>? objectives,
    List<LessonSection>? sections,
    List<ActivityModel>? activities,
    DesignRecommendation? recommendation,
    List<String>? warnings,
    String? errorMessage,
    DateTime? analyzedAt,
  }) {
    return LessonAnalysis(
      status: status ?? this.status,
      detectedTitle: detectedTitle ?? this.detectedTitle,
      objectives: objectives ?? this.objectives,
      sections: sections ?? this.sections,
      activities: activities ?? this.activities,
      recommendation: recommendation ?? this.recommendation,
      warnings: warnings ?? this.warnings,
      errorMessage: errorMessage ?? this.errorMessage,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }
}
