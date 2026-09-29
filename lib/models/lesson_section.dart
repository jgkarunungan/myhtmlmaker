enum SectionType {
  introduction('Introduction'),
  objective('Objective'),
  discussion('Discussion'),
  example('Example'),
  quote('Quote'),
  activity('Activity'),
  assessment('Assessment'),
  reflection('Reflection'),
  summary('Summary'),
  other('Other');

  final String label;
  const SectionType(this.label);

  static SectionType fromString(String val) {
    for (final t in values) {
      if (t.name.toLowerCase() == val.toLowerCase() ||
          t.label.toLowerCase() == val.toLowerCase()) {
        return t;
      }
    }
    return SectionType.other;
  }
}

class LessonSection {
  final String id;
  final int sourceOrder;
  final String title;
  final SectionType type;
  final String content;

  const LessonSection({
    required this.id,
    this.sourceOrder = 0,
    required this.title,
    required this.type,
    required this.content,
  });

  LessonSection copyWith({
    String? id,
    int? sourceOrder,
    String? title,
    SectionType? type,
    String? content,
  }) {
    return LessonSection(
      id: id ?? this.id,
      sourceOrder: sourceOrder ?? this.sourceOrder,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
    );
  }
}
