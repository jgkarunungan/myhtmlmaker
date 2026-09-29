/// Utilities for safe HTML rendering and text formatting.
class HtmlUtils {
  /// Escapes special HTML characters to prevent XSS and document corruption.
  static String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Converts raw lesson text into safe HTML paragraphs, headings, and lists.
  static String formatTextToHtmlParagraphs(String rawText) {
    if (rawText.trim().isEmpty) {
      return '<p class="empty-content">No content provided.</p>';
    }

    final lines = rawText.split(RegExp(r'\r?\n'));
    final StringBuffer buffer = StringBuffer();
    bool inUnorderedList = false;
    bool inOrderedList = false;

    void closeLists() {
      if (inUnorderedList) {
        buffer.write('</ul>\n');
        inUnorderedList = false;
      }
      if (inOrderedList) {
        buffer.write('</ol>\n');
        inOrderedList = false;
      }
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        closeLists();
        continue;
      }

      final escapedLine = escapeHtml(trimmed);

      // Detect Headings (e.g., # Heading, ## Heading, or UPPERCASE SHORT HEADINGS)
      if (trimmed.startsWith('# ')) {
        closeLists();
        buffer.write('<h2>${escapeHtml(trimmed.substring(2).trim())}</h2>\n');
      } else if (trimmed.startsWith('## ')) {
        closeLists();
        buffer.write('<h3>${escapeHtml(trimmed.substring(3).trim())}</h3>\n');
      } else if (trimmed.startsWith('### ')) {
        closeLists();
        buffer.write('<h4>${escapeHtml(trimmed.substring(4).trim())}</h4>\n');
      }
      // Unordered list items (- or *)
      else if (RegExp(r'^[\*\-]\s+').hasMatch(trimmed)) {
        if (!inUnorderedList) {
          closeLists();
          buffer.write('<ul class="lesson-list">\n');
          inUnorderedList = true;
        }
        final content = escapeHtml(trimmed.replaceFirst(RegExp(r'^[\*\-]\s+'), ''));
        buffer.write('  <li>$content</li>\n');
      }
      // Ordered list items (1. 2. etc)
      else if (RegExp(r'^\d+[\.\)]\s+').hasMatch(trimmed)) {
        if (!inOrderedList) {
          closeLists();
          buffer.write('<ol class="lesson-list">\n');
          inOrderedList = true;
        }
        final content = escapeHtml(trimmed.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), ''));
        buffer.write('  <li>$content</li>\n');
      }
      // Standard Paragraph
      else {
        closeLists();
        buffer.write('<p>$escapedLine</p>\n');
      }
    }

    closeLists();
    return buffer.toString();
  }
}
