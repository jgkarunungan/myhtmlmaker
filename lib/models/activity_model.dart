enum ActivityType {
  multipleChoice('Multiple Choice'),
  trueFalse('True / False'),
  identification('Identification'),
  matching('Matching'),
  shortAnswer('Short Answer'),
  essay('Essay'),
  reflection('Reflection'),
  situationAnalysis('Situation Analysis'),
  caseStudy('Case Study'),
  performanceTask('Performance Task'),
  other('Other');

  final String label;
  const ActivityType(this.label);

  static ActivityType fromString(String val) {
    for (final t in values) {
      if (t.name.toLowerCase() == val.toLowerCase() ||
          t.label.toLowerCase() == val.toLowerCase()) {
        return t;
      }
    }
    return ActivityType.other;
  }
}

enum GradingMode {
  automatic('Automatic'),
  teacher('Teacher Scored'),
  aiAssistedTeacher('AI-Assisted Teacher Scoring');

  final String label;
  const GradingMode(this.label);

  static GradingMode fromString(String val) {
    for (final m in values) {
      if (m.name.toLowerCase() == val.toLowerCase() ||
          m.label.toLowerCase() == val.toLowerCase()) {
        return m;
      }
    }
    return GradingMode.teacher;
  }
}

enum AnswerStatus {
  provided('Provided'),
  inferredHighConfidence('Inferred (High Confidence)'),
  missing('Missing');

  final String label;
  const AnswerStatus(this.label);

  static AnswerStatus fromString(String val) {
    for (final s in values) {
      if (s.name.toLowerCase() == val.toLowerCase() ||
          s.label.toLowerCase() == val.toLowerCase()) {
        return s;
      }
    }
    return AnswerStatus.missing;
  }
}

enum RubricType {
  teacherProvided('Teacher Provided'),
  aiSuggested('AI Suggested');

  final String label;
  const RubricType(this.label);

  static RubricType fromString(String val) {
    for (final r in values) {
      if (r.name.toLowerCase() == val.toLowerCase() ||
          r.label.toLowerCase() == val.toLowerCase()) {
        return r;
      }
    }
    return RubricType.aiSuggested;
  }
}

class QuestionModel {
  final String id;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final AnswerStatus answerStatus;

  const QuestionModel({
    required this.id,
    required this.questionText,
    this.options = const [],
    this.correctAnswer = '',
    this.answerStatus = AnswerStatus.missing,
  });

  QuestionModel copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    String? correctAnswer,
    AnswerStatus? answerStatus,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      answerStatus: answerStatus ?? this.answerStatus,
    );
  }
}

class RubricCriteria {
  final String id;
  final String description;
  final int maxPoints;

  const RubricCriteria({
    required this.id,
    required this.description,
    required this.maxPoints,
  });

  RubricCriteria copyWith({
    String? id,
    String? description,
    int? maxPoints,
  }) {
    return RubricCriteria(
      id: id ?? this.id,
      description: description ?? this.description,
      maxPoints: maxPoints ?? this.maxPoints,
    );
  }
}

class RubricModel {
  final String title;
  final RubricType type;
  final List<RubricCriteria> criteriaList;

  const RubricModel({
    required this.title,
    this.type = RubricType.aiSuggested,
    this.criteriaList = const [],
  });

  RubricModel copyWith({
    String? title,
    RubricType? type,
    List<RubricCriteria>? criteriaList,
  }) {
    return RubricModel(
      title: title ?? this.title,
      type: type ?? this.type,
      criteriaList: criteriaList ?? this.criteriaList,
    );
  }
}

class ActivityModel {
  final String id;
  final int sourceOrder;
  final String title;
  final String instructions;
  final ActivityType type;
  final int points;
  final GradingMode gradingMode;
  final List<QuestionModel> questions;
  final RubricModel? rubric;

  const ActivityModel({
    required this.id,
    this.sourceOrder = 0,
    required this.title,
    required this.instructions,
    required this.type,
    this.points = 10,
    this.gradingMode = GradingMode.teacher,
    this.questions = const [],
    this.rubric,
  });

  ActivityModel copyWith({
    String? id,
    int? sourceOrder,
    String? title,
    String? instructions,
    ActivityType? type,
    int? points,
    GradingMode? gradingMode,
    List<QuestionModel>? questions,
    RubricModel? rubric,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      sourceOrder: sourceOrder ?? this.sourceOrder,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      type: type ?? this.type,
      points: points ?? this.points,
      gradingMode: gradingMode ?? this.gradingMode,
      questions: questions ?? this.questions,
      rubric: rubric ?? this.rubric,
    );
  }
}
