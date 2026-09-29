import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../models/lesson_analysis.dart';
import '../models/lesson_model.dart';
import '../models/lesson_section.dart';

class AnalysisReviewPanel extends StatelessWidget {
  final LessonModel lesson;
  final ValueChanged<LessonModel> onLessonChanged;

  const AnalysisReviewPanel({
    super.key,
    required this.lesson,
    required this.onLessonChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final analysis = lesson.analysis;

    if (analysis == null) return const SizedBox.shrink();

    final isOutdated = analysis.status == AnalysisStatus.outdated;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isOutdated ? Colors.amber.shade700 : colorScheme.primary.withAlpha(120),
          width: isOutdated ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: isOutdated ? Colors.amber.shade800 : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Structured Lesson Analysis Review',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (analysis.analyzedAt != null)
                  Text(
                    'Analyzed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Outdated Warning Banner
            if (isOutdated) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lesson text has changed since the last analysis. Analyze again to update the structured lesson.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Analysis Summary Bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip(context, 'Objectives', '${lesson.objectives.length}', Icons.flag_outlined),
                _buildStatChip(context, 'Sections', '${lesson.sections.length}', Icons.view_headline_outlined),
                _buildStatChip(context, 'Activities', '${lesson.activities.length}', Icons.quiz_outlined),
                _buildStatChip(
                  context,
                  'Automatic',
                  '${analysis.automaticCount}',
                  Icons.smart_toy_outlined,
                  color: Colors.green.shade700,
                ),
                _buildStatChip(
                  context,
                  'Teacher-Scored',
                  '${analysis.teacherScoredCount}',
                  Icons.edit_note_outlined,
                  color: Colors.blue.shade700,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI Warnings if any
            if (analysis.warnings.isNotEmpty) ...[
              Text(
                'AI Analysis Warnings',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 4),
              ...analysis.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Expandable Accordions for Objectives, Sections, Activities
            ExpansionTile(
              title: Text('Objectives (${lesson.objectives.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.flag_outlined),
              children: [_buildObjectivesList(context)],
            ),
            const Divider(height: 1),

            ExpansionTile(
              title: Text('Lesson Sections (${lesson.sections.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.segment_outlined),
              children: [_buildSectionsList(context)],
            ),
            const Divider(height: 1),

            ExpansionTile(
              title: Text('Activities & Rubrics (${lesson.activities.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.assignment_outlined),
              children: [_buildActivitiesList(context)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String val, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '$label: $val',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectivesList(BuildContext context) {
    return Column(
      children: [
        ...lesson.objectives.asMap().entries.map((entry) {
          final idx = entry.key;
          final objText = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: objText,
                    decoration: InputDecoration(
                      labelText: 'Objective ${idx + 1}',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (newVal) {
                      final updated = List<String>.from(lesson.objectives);
                      updated[idx] = newVal;
                      onLessonChanged(lesson.copyWith(objectives: updated));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    final updated = List<String>.from(lesson.objectives)..removeAt(idx);
                    onLessonChanged(lesson.copyWith(objectives: updated));
                  },
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final updated = List<String>.from(lesson.objectives)..add('New Objective');
              onLessonChanged(lesson.copyWith(objectives: updated));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Objective'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionsList(BuildContext context) {
    return Column(
      children: [
        ...lesson.sections.asMap().entries.map((entry) {
          final idx = entry.key;
          final sec = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: sec.title,
                          decoration: const InputDecoration(
                            labelText: 'Section Title',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final updatedSecs = List<LessonSection>.from(lesson.sections);
                            updatedSecs[idx] = sec.copyWith(title: v);
                            onLessonChanged(lesson.copyWith(sections: updatedSecs));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<SectionType>(
                        value: sec.type,
                        items: SectionType.values.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t.label));
                        }).toList(),
                        onChanged: (newType) {
                          if (newType != null) {
                            final updatedSecs = List<LessonSection>.from(lesson.sections);
                            updatedSecs[idx] = sec.copyWith(type: newType);
                            onLessonChanged(lesson.copyWith(sections: updatedSecs));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: sec.content,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Section Content',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final updatedSecs = List<LessonSection>.from(lesson.sections);
                      updatedSecs[idx] = sec.copyWith(content: v);
                      onLessonChanged(lesson.copyWith(sections: updatedSecs));
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivitiesList(BuildContext context) {
    return Column(
      children: [
        ...lesson.activities.asMap().entries.map((entry) {
          final idx = entry.key;
          final act = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: act.title,
                          decoration: const InputDecoration(
                            labelText: 'Activity Title',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final updatedActs = List<ActivityModel>.from(lesson.activities);
                            updatedActs[idx] = act.copyWith(title: v);
                            onLessonChanged(lesson.copyWith(activities: updatedActs));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: '${act.points}',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Points',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final p = int.tryParse(v) ?? act.points;
                            final updatedActs = List<ActivityModel>.from(lesson.activities);
                            updatedActs[idx] = act.copyWith(points: p);
                            onLessonChanged(lesson.copyWith(activities: updatedActs));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: act.instructions,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final updatedActs = List<ActivityModel>.from(lesson.activities);
                      updatedActs[idx] = act.copyWith(instructions: v);
                      onLessonChanged(lesson.copyWith(activities: updatedActs));
                    },
                  ),
                  const SizedBox(height: 8),

                  // Questions Summary & Correct Answer Edit
                  if (act.questions.isNotEmpty) ...[
                    const Text('Questions & Answers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ...act.questions.asMap().entries.map((qEntry) {
                      final qIdx = qEntry.key;
                      final q = qEntry.value;

                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Q${qIdx + 1}: ${q.questionText}', overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: q.correctAnswer,
                                decoration: InputDecoration(
                                  labelText: 'Answer (${q.answerStatus.label})',
                                  isDense: true,
                                ),
                                onChanged: (newAns) {
                                  final updatedQs = List<QuestionModel>.from(act.questions);
                                  updatedQs[qIdx] = q.copyWith(
                                    correctAnswer: newAns,
                                    answerStatus: newAns.trim().isNotEmpty
                                        ? AnswerStatus.provided
                                        : AnswerStatus.missing,
                                  );
                                  final updatedActs = List<ActivityModel>.from(lesson.activities);
                                  updatedActs[idx] = act.copyWith(questions: updatedQs);
                                  onLessonChanged(lesson.copyWith(activities: updatedActs));
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Rubric display / edit
                  if (act.rubric != null && act.rubric!.criteriaList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Rubric (${act.rubric!.type.label}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ...act.rubric!.criteriaList.map((crit) => Text('• ${crit.description} (${crit.maxPoints} pts)')),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
