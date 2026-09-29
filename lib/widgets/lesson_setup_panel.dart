import 'package:flutter/material.dart';
import '../config/student_config.dart';
import '../models/design_config.dart';

class LessonSetupPanel extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController subjectController;
  final String selectedGrade;
  final VisualProfile selectedProfile;
  final DesignIntensity selectedIntensity;
  final ValueChanged<String?> onGradeChanged;
  final ValueChanged<VisualProfile?> onProfileChanged;
  final ValueChanged<DesignIntensity> onIntensityChanged;

  const LessonSetupPanel({
    super.key,
    required this.titleController,
    required this.subjectController,
    required this.selectedGrade,
    required this.selectedProfile,
    required this.selectedIntensity,
    required this.onGradeChanged,
    required this.onProfileChanged,
    required this.onIntensityChanged,
  });

  static const List<VisualProfile> _selectableProfiles = [
    VisualProfile.auto,
    VisualProfile.modernAcademic,
    VisualProfile.editorial,
    VisualProfile.reflectiveJournal,
    VisualProfile.interactiveCards,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allowedGradeLevels = StudentConfig.allowedGradeLevels;

    final initialGrade = allowedGradeLevels.contains(selectedGrade)
        ? selectedGrade
        : allowedGradeLevels.first;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lesson Setup',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Module Title
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Module Title *',
                hintText: 'e.g., Introduction to Photosynthesis',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Responsive Layout for Subject and Grade Level
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                final subjectField = TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'e.g., General Biology',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                );

                final gradeDropdown = DropdownButtonFormField<String>(
                  initialValue: initialGrade,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Grade Level *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: allowedGradeLevels.map((gl) {
                    return DropdownMenuItem<String>(
                      value: gl,
                      child: Text(
                        gl,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onGradeChanged,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      subjectField,
                      const SizedBox(height: 12),
                      gradeDropdown,
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: subjectField),
                      const SizedBox(width: 12),
                      Expanded(child: gradeDropdown),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // Visual Profile Dropdown
            DropdownButtonFormField<VisualProfile>(
              initialValue: selectedProfile,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Visual Profile',
                border: OutlineInputBorder(),
                isDense: true,
                helperText: 'Select a theme profile or Auto for deterministic seed selection.',
              ),
              items: _selectableProfiles.map((p) {
                return DropdownMenuItem<VisualProfile>(
                  value: p,
                  child: Text(
                    p.label,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onProfileChanged,
            ),
            const SizedBox(height: 16),

            // Design Intensity
            Text(
              'Design Intensity',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DesignIntensity.values.map((intensity) {
                final isSelected = intensity == selectedIntensity;
                return ChoiceChip(
                  label: Text(intensity.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      onIntensityChanged(intensity);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
