import 'package:flutter/material.dart';

class LessonEditor extends StatelessWidget {
  final TextEditingController controller;

  const LessonEditor({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                Icon(Icons.description, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lesson Content Input',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Raw Text Editor',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 18,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Paste your complete lesson here',
                hintText:
                    'Paste complete lesson text including title, objectives, discussion, examples, activities, and questions...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surfaceContainerLowest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
