import 'activity_model.dart';
import 'design_config.dart';
import 'lesson_analysis.dart';
import 'lesson_section.dart';

class LessonModel {
  final String id;
  final String title;
  final String subject;
  final String gradeLevel;
  final String rawLessonText;
  final List<String> objectives;
  final List<LessonSection> sections;
  final List<ActivityModel> activities;
  final DesignConfig designConfig;
  final LessonAnalysis? analysis;

  const LessonModel({
    required this.id,
    this.title = '',
    this.subject = '',
    this.gradeLevel = '',
    this.rawLessonText = '',
    this.objectives = const [],
    this.sections = const [],
    this.activities = const [],
    this.designConfig = const DesignConfig(),
    this.analysis,
  });

  bool get hasStructuredAnalysis =>
      analysis != null &&
      (analysis!.status == AnalysisStatus.success ||
          analysis!.status == AnalysisStatus.outdated);

  LessonModel copyWith({
    String? id,
    String? title,
    String? subject,
    String? gradeLevel,
    String? rawLessonText,
    List<String>? objectives,
    List<LessonSection>? sections,
    List<ActivityModel>? activities,
    DesignConfig? designConfig,
    LessonAnalysis? analysis,
  }) {
    return LessonModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      rawLessonText: rawLessonText ?? this.rawLessonText,
      objectives: objectives ?? this.objectives,
      sections: sections ?? this.sections,
      activities: activities ?? this.activities,
      designConfig: designConfig ?? this.designConfig,
      analysis: analysis ?? this.analysis,
    );
  }
}
