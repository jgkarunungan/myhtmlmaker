import 'dart:convert';

import '../config/student_config.dart';
import '../models/activity_model.dart';
import '../models/design_config.dart';
import '../models/generated_module.dart';
import '../models/lesson_model.dart';
import '../models/lesson_section.dart';
import '../utils/html_utils.dart';
import '../utils/module_id_generator.dart';
import '../utils/slug_utils.dart';
import 'design_engine.dart';
import 'firebase_config_service.dart';

/// Engine responsible for converting [LessonModel] and [DesignConfig] into
/// standalone, student-facing HTML/CSS/JavaScript web modules.
class HtmlGeneratorService {
  final FirebaseConfigService _firebaseConfigService;

  HtmlGeneratorService({FirebaseConfigService? firebaseConfigService})
      : _firebaseConfigService = firebaseConfigService ?? const FirebaseConfigService();

  /// Generates a standalone web module from [lesson] and [designConfig].
  Future<GeneratedModule> generateModule({
    required LessonModel lesson,
    required DesignConfig designConfig,
    Map<String, List<String>>? gradeSectionsSnapshot,
  }) async {
    final String moduleId = lesson.id.trim().isEmpty
        ? ModuleIdGenerator.generate()
        : lesson.id;

    final String slug = SlugUtils.generateSlug(lesson.title);
    final ResolvedDesignProperties design = DesignEngine.resolve(designConfig);

    // Capture current Grade & Section snapshot if not explicitly provided
    final Map<String, List<String>> activeSnapshot = gradeSectionsSnapshot != null
        ? Map.from(gradeSectionsSnapshot)
        : Map.from(StudentConfig.gradeSectionsMap);

    final String htmlContent = _generateHtml(lesson, design, activeSnapshot);
    final String cssContent = _generateCss(design);
    final String jsContent = _generateJavaScript(activeSnapshot);
    final String firebaseJsContent = _firebaseConfigService.generateFirebaseJs(
      moduleId: moduleId,
      lesson: lesson,
    );

    return GeneratedModule(
      moduleId: moduleId,
      title: lesson.title.trim().isEmpty ? 'Self-Learning Module' : lesson.title.trim(),
      slug: slug,
      html: htmlContent,
      css: cssContent,
      javaScript: jsContent,
      firebaseJavaScript: firebaseJsContent,
      designConfig: designConfig.copyWith(
        visualProfile: design.resolvedProfile,
        designSeed: design.seed,
      ),
      generatedAt: DateTime.now(),
    );
  }

  // ===========================================================================
  // HTML GENERATION
  // ===========================================================================

  String _generateHtml(
    LessonModel lesson,
    ResolvedDesignProperties design,
    Map<String, List<String>> gradeSectionsSnapshot,
  ) {
    final String safeTitle = HtmlUtils.escapeHtml(
      lesson.title.trim().isEmpty ? 'Self-Learning Module' : lesson.title.trim(),
    );
    final String safeSubject = HtmlUtils.escapeHtml(
      lesson.subject.trim().isEmpty ? 'General Subject' : lesson.subject.trim(),
    );
    final String safeGrade = HtmlUtils.escapeHtml(
      lesson.gradeLevel.trim().isEmpty ? 'Grade 11' : lesson.gradeLevel.trim(),
    );

    final String mainBodyHtml = _renderLessonBody(lesson);

    // Build Grade Level dropdown options from snapshot keys
    final gradeLevels = gradeSectionsSnapshot.keys.toList();
    final String gradeLevelOptions = (gradeLevels.isNotEmpty ? gradeLevels : ['Grade 11', 'Grade 12']).map((gl) {
      final safeGl = HtmlUtils.escapeHtml(gl);
      return '                <option value="$safeGl">$safeGl</option>';
    }).join('\n');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$safeTitle - Self-Learning Module</title>
  <link rel="stylesheet" href="css/module.css">
</head>
<body class="profile-${design.resolvedProfile.name} hero-${design.heroStyle} card-${design.cardTreatment}">

  <!-- Progress Bar Header -->
  <div id="progress-bar-container" class="progress-bar-container">
    <div id="progress-bar" class="progress-bar"></div>
  </div>

  <div class="module-wrapper">
    <!-- Hero / Module Header Area -->
    <header class="module-hero">
      <div class="hero-content">
        <div class="hero-badges">
          <span class="badge subject-badge">$safeSubject</span>
          <span class="badge grade-badge">$safeGrade</span>
        </div>
        <h1 class="module-title">$safeTitle</h1>
        <p class="hero-subtitle">Self-Learning Module • Self-Paced Learning</p>
        <div id="cloud-status-badge" class="cloud-status-badge status-connecting">Connecting...</div>
      </div>
    </header>

    <!-- Student Information Form Section -->
    <section id="student-form-section" class="card student-card">
      <div class="card-header">
        <h2>Student Information</h2>
        <p class="card-description">Please enter your details to unlock and begin this module.</p>
      </div>
      <form id="student-info-form" class="student-form" novalidate>
        <div class="form-grid">
          <div class="form-group">
            <label for="firstName">First Name <span class="required">*</span></label>
            <input type="text" id="firstName" name="firstName" placeholder="Enter first name" required>
            <span class="error-msg" id="error-firstName">First name is required.</span>
          </div>

          <div class="form-group">
            <label for="surname">Surname <span class="required">*</span></label>
            <input type="text" id="surname" name="surname" placeholder="Enter surname" required>
            <span class="error-msg" id="error-surname">Surname is required.</span>
          </div>

          <div class="form-group">
            <label for="middleName">Middle Name <span class="required">*</span></label>
            <input type="text" id="middleName" name="middleName" placeholder="Enter middle name" required>
            <span class="error-msg" id="error-middleName">Middle name is required.</span>
          </div>

          <div class="form-group">
            <label for="gradeLevel">Grade Level <span class="required">*</span></label>
            <select id="gradeLevel" name="gradeLevel" required>
              <option value="">-- Select Grade Level --</option>
$gradeLevelOptions
            </select>
            <span class="error-msg" id="error-gradeLevel">Please select your grade level.</span>
          </div>

          <div class="form-group">
            <label for="section">Section <span class="required">*</span></label>
            <select id="section" name="section" required>
              <option value="">-- Select Section --</option>
            </select>
            <span class="error-msg" id="error-section">Please select your section.</span>
          </div>

          <div class="form-group full-width">
            <label for="lrn">LRN <span class="optional-note">(${StudentConfig.lrnNote})</span></label>
            <input type="text" id="lrn" name="lrn" placeholder="e.g., 123456789012">
          </div>
        </div>

        <div class="form-actions">
          <button type="submit" id="btn-start-lesson" class="btn btn-primary">Start Lesson</button>
        </div>
      </form>
    </section>

    <!-- Main Lesson Content Section (Unlocked via Start Lesson) -->
    <main id="lesson-content-section" class="lesson-content-section locked">
      <div class="card content-card">
        <div class="lesson-body">
$mainBodyHtml
        </div>
      </div>

      <!-- Final Submit Activities Section -->
      <section id="submit-section" class="card submit-card">
        <div id="submission-status-banner" class="submission-banner" style="display:none;"></div>
        <h2>Submit Activities</h2>
        <p class="card-description">Ready to complete your module? Submit your answers for teacher review.</p>
        <button type="button" id="btn-submit-activities" class="btn btn-primary">Submit Activities</button>
        <span class="submit-feedback" id="submit-feedback"></span>
      </section>

      <!-- End of Module Section -->
      <section class="end-module-card card">
        <div class="end-module-content">
          <div class="check-icon">&#10003;</div>
          <h2>Lesson Completed</h2>
          <p>You have reached the end of this lesson module.</p>
        </div>
      </section>
    </main>

    <!-- Module Footer -->
    <footer class="module-footer">
      <p>Self-Learning Module Studio • Authoring Tool</p>
    </footer>
  </div>

  <script type="module" src="js/firebase.js"></script>
  <script src="js/module.js"></script>
</body>
</html>
''';
  }

  /// Renders lesson text or structured sections and activities into HTML.
  String _renderLessonBody(LessonModel lesson) {
    final StringBuffer buffer = StringBuffer();

    // Render Objectives block if present
    if (lesson.objectives.isNotEmpty) {
      buffer.write('<div class="section section-objectives card-inset">\n');
      buffer.write('  <h2>Learning Objectives</h2>\n');
      buffer.write('  <ul class="lesson-list">\n');
      for (final obj in lesson.objectives) {
        buffer.write('    <li>${HtmlUtils.escapeHtml(obj)}</li>\n');
      }
      buffer.write('  </ul>\n');
      buffer.write('</div>\n\n');
    }

    // Render Sections
    if (lesson.sections.isNotEmpty) {
      for (final section in lesson.sections) {
        buffer.write(_renderSection(section));
      }
    } else if (lesson.objectives.isEmpty) {
      // General discussion body for raw lesson text fallback
      buffer.write(HtmlUtils.formatTextToHtmlParagraphs(lesson.rawLessonText));
    }

    // Render Activities if present
    if (lesson.activities.isNotEmpty) {
      buffer.write('<div class="section section-activities-wrapper">\n');
      buffer.write('  <h2>Learning Activities & Assessments</h2>\n');
      for (final act in lesson.activities) {
        buffer.write(_renderActivityCard(act));
      }
      buffer.write('</div>\n');
    }

    return buffer.toString();
  }

  /// Helper boundary for individual section rendering.
  String _renderSection(LessonSection section) {
    final safeTitle = HtmlUtils.escapeHtml(section.title);
    final safeContent = HtmlUtils.formatTextToHtmlParagraphs(section.content);

    return switch (section.type) {
      SectionType.introduction => '''
<div class="section section-introduction">
  ${safeTitle.isNotEmpty ? '<h2>$safeTitle</h2>' : ''}
  $safeContent
</div>\n''',
      SectionType.objective => '''
<div class="section section-objective">
  ${safeTitle.isNotEmpty ? '<h2>$safeTitle</h2>' : ''}
  $safeContent
</div>\n''',
      SectionType.discussion => '''
<div class="section section-discussion">
  ${safeTitle.isNotEmpty ? '<h2>$safeTitle</h2>' : ''}
  $safeContent
</div>\n''',
      SectionType.example => '''
<div class="section section-example card-inset">
  ${safeTitle.isNotEmpty ? '<h3>$safeTitle</h3>' : ''}
  $safeContent
</div>\n''',
      SectionType.quote => '''
<blockquote class="section section-quote">
  $safeContent
</blockquote>\n''',
      SectionType.summary => '''
<div class="section section-summary">
  ${safeTitle.isNotEmpty ? '<h2>$safeTitle</h2>' : ''}
  $safeContent
</div>\n''',
      _ => '''
<div class="section section-general">
  ${safeTitle.isNotEmpty ? '<h2>$safeTitle</h2>' : ''}
  $safeContent
</div>\n''',
    };
  }

  /// Renders individual activity cards with controls and rubric details.
  String _renderActivityCard(ActivityModel act) {
    final safeTitle = HtmlUtils.escapeHtml(act.title);
    final safeInstructions = HtmlUtils.escapeHtml(act.instructions);

    final StringBuffer buffer = StringBuffer();
    buffer.write('<div class="activity-card card-inset" data-activity-id="${act.id}">\n');
    buffer.write('  <div class="activity-header">\n');
    buffer.write('    <h3>$safeTitle <span class="badge points-badge">${act.points} pts</span></h3>\n');
    if (safeInstructions.isNotEmpty) {
      buffer.write('    <p class="activity-instructions">$safeInstructions</p>\n');
    }
    buffer.write('  </div>\n');

    // Render Questions
    if (act.questions.isNotEmpty) {
      buffer.write('  <div class="questions-list">\n');
      for (int i = 0; i < act.questions.length; i++) {
        final q = act.questions[i];
        final safeQText = HtmlUtils.escapeHtml(q.questionText);
        buffer.write('    <div class="question-item" data-question-id="${q.id}">\n');
        buffer.write('      <p class="question-text"><strong>Q${i + 1}.</strong> $safeQText</p>\n');

        if (act.type == ActivityType.multipleChoice && q.options.isNotEmpty) {
          buffer.write('      <div class="options-group">\n');
          for (final opt in q.options) {
            final safeOpt = HtmlUtils.escapeHtml(opt);
            buffer.write('        <label class="radio-label">\n');
            buffer.write('          <input type="radio" name="q_${q.id}" value="$safeOpt"> $safeOpt\n');
            buffer.write('        </label>\n');
          }
          buffer.write('      </div>\n');
        } else if (act.type == ActivityType.trueFalse) {
          buffer.write('      <div class="options-group">\n');
          buffer.write('        <label class="radio-label"><input type="radio" name="q_${q.id}" value="True"> True</label>\n');
          buffer.write('        <label class="radio-label"><input type="radio" name="q_${q.id}" value="False"> False</label>\n');
          buffer.write('      </div>\n');
        } else {
          buffer.write('      <textarea class="answer-input" rows="3" placeholder="Type your response here..."></textarea>\n');
        }
        buffer.write('    </div>\n');
      }
      buffer.write('  </div>\n');
    }

    // Render Rubric if present
    if (act.rubric != null && act.rubric!.criteriaList.isNotEmpty) {
      buffer.write('  <div class="activity-rubric">\n');
      buffer.write('    <h4>Evaluation Rubric (${act.rubric!.type.label})</h4>\n');
      buffer.write('    <table class="rubric-table">\n');
      buffer.write('      <thead><tr><th>Criteria</th><th>Max Points</th></tr></thead>\n');
      buffer.write('      <tbody>\n');
      for (final crit in act.rubric!.criteriaList) {
        buffer.write('        <tr><td>${HtmlUtils.escapeHtml(crit.description)}</td><td>${crit.maxPoints}</td></tr>\n');
      }
      buffer.write('      </tbody>\n');
      buffer.write('    </table>\n');
      buffer.write('  </div>\n');
    }

    buffer.write('</div>\n');
    return buffer.toString();
  }

  // ===========================================================================
  // CSS GENERATION
  // ===========================================================================

  String _generateCss(ResolvedDesignProperties design) {
    return '''
/* Generated by Self-Learning Module Studio */
/* Profile: ${design.resolvedProfile.label} | Seed: ${design.seed} */

:root {
  --primary: ${design.primaryColor};
  --primary-container: ${design.primaryContainerColor};
  --accent: ${design.accentColor};
  --bg: ${design.backgroundColor};
  --surface: ${design.surfaceColor};
  --text: ${design.textColor};
  --text-muted: ${design.textMutedColor};
  --font-header: ${design.fontFamilyHeader};
  --font-body: ${design.fontFamilyBody};
  --radius: ${design.borderRadius};
  --shadow: ${design.boxShadow};
  --spacing: ${design.spacingScale};
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: var(--font-body);
  background-color: var(--bg);
  color: var(--text);
  line-height: 1.7;
  padding-bottom: 3rem;
  -webkit-font-smoothing: antialiased;
}

/* Progress Bar */
.progress-bar-container {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 5px;
  background-color: rgba(0, 0, 0, 0.08);
  z-index: 1000;
}

.progress-bar {
  height: 100%;
  width: 0%;
  background-color: var(--accent);
  transition: width 0.2s ease-out;
}

/* Cloud Status Badge */
.cloud-status-badge {
  display: inline-block;
  font-size: 0.8rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 50px;
  margin-top: 0.5rem;
  background-color: #E2E8F0;
  color: #475569;
}

.cloud-status-badge.status-connecting { background-color: #FEF3C7; color: #92400E; }
.cloud-status-badge.status-connected { background-color: #D1FAE5; color: #065F46; }
.cloud-status-badge.status-saving { background-color: #E0F2FE; color: #075985; }
.cloud-status-badge.status-saved { background-color: #D1FAE5; color: #065F46; }
.cloud-status-badge.status-preview { background-color: #F1F5F9; color: #475569; }
.cloud-status-badge.status-offline { background-color: #FFEDD5; color: #9A3412; }
.cloud-status-badge.status-error { background-color: #FEE2E2; color: #991B1B; }
.cloud-status-badge.status-submitted { background-color: #D1FAE5; color: #065F46; }

/* Layout Container */
.module-wrapper {
  max-width: 860px;
  margin: 0 auto;
  padding: 1.5rem 1rem;
}

/* Hero Area */
.module-hero {
  background: var(--surface);
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  padding: 2.5rem 2rem;
  margin-bottom: var(--spacing);
  border-top: 5px solid var(--primary);
}

.hero-badges {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.badge {
  font-size: 0.85rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 50px;
}

.subject-badge {
  background-color: var(--primary-container);
  color: var(--primary);
}

.grade-badge {
  background-color: rgba(0, 0, 0, 0.05);
  color: var(--text-muted);
}

.points-badge {
  background-color: var(--accent);
  color: #FFFFFF;
  float: right;
  font-size: 0.8rem;
}

.module-title {
  font-family: var(--font-header);
  font-size: 2rem;
  font-weight: 700;
  color: var(--primary);
  line-height: 1.3;
  margin-bottom: 0.5rem;
}

.hero-subtitle {
  color: var(--text-muted);
  font-size: 0.95rem;
}

/* Cards */
.card {
  background-color: var(--surface);
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  padding: 2rem;
  margin-bottom: var(--spacing);
  border: 1px solid rgba(0,0,0,0.06);
}

.card-inset {
  background-color: var(--primary-container);
  border-left: 4px solid var(--primary);
  padding: 1.25rem 1.5rem;
  border-radius: calc(var(--radius) / 2);
  margin: 1.5rem 0;
}

/* Student Form */
.student-card h2 {
  font-family: var(--font-header);
  color: var(--primary);
  margin-bottom: 0.25rem;
}

.card-description {
  color: var(--text-muted);
  font-size: 0.95rem;
  margin-bottom: 1.5rem;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group.full-width {
  grid-column: 1 / -1;
}

label {
  font-size: 0.9rem;
  font-weight: 600;
  margin-bottom: 0.4rem;
  color: var(--text);
}

.required {
  color: #DC2626;
}

.optional-note {
  font-weight: normal;
  font-size: 0.8rem;
  color: var(--text-muted);
}

input[type="text"], select, textarea {
  font-family: inherit;
  font-size: 0.95rem;
  padding: 0.65rem 0.85rem;
  border: 1.5px solid #CBD5E1;
  border-radius: calc(var(--radius) / 2);
  background-color: #FFFFFF;
  color: var(--text);
  min-height: 44px;
  transition: border-color 0.2s, box-shadow 0.2s;
  width: 100%;
}

input[type="text"]:focus, select:focus, textarea:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-container);
}

input.has-error, select.has-error {
  border-color: #DC2626;
}

.error-msg {
  color: #DC2626;
  font-size: 0.8rem;
  margin-top: 0.25rem;
  display: none;
}

.error-msg.visible {
  display: block;
}

.form-actions {
  margin-top: 1.5rem;
  display: flex;
  justify-content: flex-end;
}

.btn {
  font-family: inherit;
  font-size: 1rem;
  font-weight: 600;
  padding: 0.75rem 1.75rem;
  border-radius: var(--radius);
  border: none;
  cursor: pointer;
  transition: transform 0.1s, background-color 0.2s;
  min-height: 44px;
}

.btn:active {
  transform: scale(0.98);
}

.btn-primary {
  background-color: var(--primary);
  color: #FFFFFF;
}

.btn-primary:hover {
  filter: brightness(1.1);
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Submit Activities Section */
.submit-card {
  margin-top: 2rem;
  text-align: center;
}

.submission-banner {
  background-color: #D1FAE5;
  color: #065F46;
  border: 1px solid #10B981;
  padding: 0.75rem 1rem;
  border-radius: calc(var(--radius) / 2);
  margin-bottom: 1rem;
  font-weight: 600;
}

.submit-feedback {
  display: block;
  margin-top: 0.75rem;
  font-size: 0.9rem;
  font-weight: 600;
}

.submit-feedback.error { color: #DC2626; }
.submit-feedback.success { color: #059669; }

/* Lesson Content Area */
.lesson-content-section.locked {
  display: none;
}

.lesson-body h2 {
  font-family: var(--font-header);
  color: var(--primary);
  font-size: 1.5rem;
  margin: 1.75rem 0 0.75rem 0;
  border-bottom: 2px solid var(--primary-container);
  padding-bottom: 0.3rem;
}

.lesson-body h3 {
  font-family: var(--font-header);
  color: var(--text);
  font-size: 1.25rem;
  margin: 1.5rem 0 0.5rem 0;
}

.lesson-body p {
  margin-bottom: 1.25rem;
  color: var(--text);
}

.lesson-list {
  margin: 1rem 0 1.25rem 1.75rem;
}

.lesson-list li {
  margin-bottom: 0.4rem;
}

blockquote {
  border-left: 4px solid var(--accent);
  padding: 1rem 1.25rem;
  background-color: rgba(0,0,0,0.02);
  margin: 1.5rem 0;
  font-style: italic;
  color: var(--text-muted);
}

/* Activities Styling */
.question-item {
  margin: 1rem 0;
  padding: 0.75rem;
  background: rgba(255, 255, 255, 0.7);
  border-radius: calc(var(--radius) / 2);
}

.options-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.radio-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: normal;
  cursor: pointer;
}

.rubric-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 0.75rem;
  font-size: 0.85rem;
}

.rubric-table th, .rubric-table td {
  border: 1px solid rgba(0,0,0,0.1);
  padding: 0.5rem;
  text-align: left;
}

.rubric-table th {
  background: var(--primary-container);
  color: var(--primary);
}

/* Hero Style Variations */
body.hero-centered-hero .module-hero {
  text-align: center;
}
body.hero-centered-hero .hero-badges {
  justify-content: center;
}

body.hero-card-hero .module-hero {
  border-top: none;
  border: 2px solid var(--primary);
  background: var(--surface);
}

body.hero-accent-left-hero .module-hero {
  border-top: none;
  border-left: 6px solid var(--primary);
}

body.hero-banner-hero .module-hero {
  border-top: 5px solid var(--primary);
}

/* Card Treatment Variations */
body.card-bordered-card .card {
  box-shadow: none;
  border: 2px solid rgba(0, 0, 0, 0.12);
}

body.card-top-accent-card .card {
  border-top: 4px solid var(--accent);
}

body.card-minimal-card .card {
  box-shadow: none;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: var(--surface);
}

body.card-elevated-card .card {
  box-shadow: var(--shadow);
}

/* Visual Profile Specific Variations */
body.profile-editorial .module-title {
  font-family: var(--font-header);
  font-size: 2.25rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}

body.profile-editorial blockquote {
  font-size: 1.05rem;
  border-left-width: 3px;
  background-color: var(--primary-container);
}

body.profile-reflectiveJournal .module-hero {
  background: var(--primary-container);
  border-top: none;
  border-radius: calc(var(--radius) * 1.5);
}

body.profile-reflectiveJournal .subject-badge {
  background-color: var(--surface);
}

body.profile-interactiveCards .card {
  border-radius: calc(var(--radius) * 1.25);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

/* End Module Section */
.end-module-card {
  text-align: center;
  padding: 3rem 2rem;
  background: var(--surface);
}

.check-icon {
  width: 56px;
  height: 56px;
  background-color: var(--primary-container);
  color: var(--primary);
  font-size: 1.8rem;
  font-weight: bold;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
}

.end-module-card h2 {
  font-family: var(--font-header);
  color: var(--primary);
  margin-bottom: 0.5rem;
}

.end-module-card p {
  color: var(--text-muted);
}

.module-footer {
  text-align: center;
  color: var(--text-muted);
  font-size: 0.85rem;
  margin-top: 2rem;
}

/* Responsive Breakpoints */
@media (max-width: 640px) {
  .form-grid {
    grid-template-columns: 1fr;
  }

  .module-hero {
    padding: 1.75rem 1.25rem;
  }

  .card {
    padding: 1.25rem;
  }

  .module-title {
    font-size: 1.5rem;
  }
}
''';
  }

  // ===========================================================================
  // JAVASCRIPT GENERATION
  // ===========================================================================

  String _generateJavaScript(Map<String, List<String>> gradeSectionsSnapshot) {
    final String jsonMap = jsonEncode(gradeSectionsSnapshot);

    return '''
// Self-Learning Module Client Controller
document.addEventListener('DOMContentLoaded', function () {
  const form = document.getElementById('student-info-form');
  const studentFormSection = document.getElementById('student-form-section');
  const lessonSection = document.getElementById('lesson-content-section');
  const progressBar = document.getElementById('progress-bar');

  const gradeLevelSelect = document.getElementById('gradeLevel');
  const sectionSelect = document.getElementById('section');

  const GRADE_SECTIONS = $jsonMap;

  // Populate Section options dynamically based on selected Grade Level
  if (gradeLevelSelect && sectionSelect) {
    gradeLevelSelect.addEventListener('change', function () {
      const selectedGrade = gradeLevelSelect.value;
      sectionSelect.innerHTML = '<option value="">-- Select Section --</option>';

      const sections = GRADE_SECTIONS[selectedGrade] || [];
      sections.forEach(function (sec) {
        const opt = document.createElement('option');
        opt.value = sec;
        opt.textContent = sec;
        sectionSelect.appendChild(opt);
      });
    });
  }

  const requiredFields = ['firstName', 'surname', 'middleName', 'gradeLevel', 'section'];

  // Form Validation & Start Lesson
  if (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      let isValid = true;

      requiredFields.forEach(function (fieldId) {
        const input = document.getElementById(fieldId);
        const errorMsg = document.getElementById('error-' + fieldId);

        if (!input || !input.value.trim()) {
          isValid = false;
          if (input) input.classList.add('has-error');
          if (errorMsg) errorMsg.classList.add('visible');
        } else {
          if (input) input.classList.remove('has-error');
          if (errorMsg) errorMsg.classList.remove('visible');
        }
      });

      if (isValid) {
        // Unlock lesson content
        if (lessonSection) {
          lessonSection.classList.remove('locked');
        }
        // Collapse / hide student form
        if (studentFormSection) {
          studentFormSection.style.display = 'none';
        }

        // Smooth scroll to lesson content
        lessonSection.scrollIntoView({ behavior: 'smooth' });

        // Recalculate progress bar
        updateProgress();

        if (window.ModuleFirebase && window.ModuleFirebase.debouncedSaveDraft) {
          window.ModuleFirebase.debouncedSaveDraft();
        }
      }
    });

    // Real-time error removal on input
    requiredFields.forEach(function (fieldId) {
      const input = document.getElementById(fieldId);
      if (input) {
        input.addEventListener('input', function () {
          if (input.value.trim()) {
            input.classList.remove('has-error');
            const errorMsg = document.getElementById('error-' + fieldId);
            if (errorMsg) errorMsg.classList.remove('visible');
          }
        });
      }
    });
  }

  // Trigger debounced save on activity response inputs
  document.querySelectorAll('.activity-card input, .activity-card textarea').forEach(function(el) {
    el.addEventListener('change', function() {
      if (window.ModuleFirebase && window.ModuleFirebase.debouncedSaveDraft) {
        window.ModuleFirebase.debouncedSaveDraft();
      }
    });
    el.addEventListener('input', function() {
      if (window.ModuleFirebase && window.ModuleFirebase.debouncedSaveDraft) {
        window.ModuleFirebase.debouncedSaveDraft();
      }
    });
  });

  // Final Submit Activities Button
  const btnSubmit = document.getElementById('btn-submit-activities');
  const submitFeedback = document.getElementById('submit-feedback');

  if (btnSubmit) {
    btnSubmit.addEventListener('click', async function() {
      // Validate required student info
      let studentValid = true;
      requiredFields.forEach(function (fieldId) {
        const input = document.getElementById(fieldId);
        if (!input || !input.value.trim()) {
          studentValid = false;
        }
      });

      if (!studentValid) {
        if (submitFeedback) {
          submitFeedback.textContent = 'Please complete required Student Information before submitting.';
          submitFeedback.className = 'submit-feedback error';
        }
        return;
      }

      const confirmed = window.confirm('Are you ready to submit your activities?');
      if (!confirmed) return;

      btnSubmit.disabled = true;
      if (submitFeedback) {
        submitFeedback.textContent = 'Submitting activities...';
        submitFeedback.className = 'submit-feedback';
      }

      try {
        if (window.ModuleFirebase && window.ModuleFirebase.submitModule) {
          await window.ModuleFirebase.submitModule();
          btnSubmit.disabled = true;
          btnSubmit.textContent = 'Activities Submitted';
          if (submitFeedback) {
            submitFeedback.textContent = 'Your activities have been submitted successfully.';
            submitFeedback.className = 'submit-feedback success';
          }
        } else {
          throw new Error('Cloud service unavailable.');
        }
      } catch (err) {
        btnSubmit.disabled = false;
        if (submitFeedback) {
          submitFeedback.textContent = 'Submission could not be sent. Your answers remain on this page. Please check your connection and try again.';
          submitFeedback.className = 'submit-feedback error';
        }
      }
    });
  }

  // Scroll Progress Tracker
  function updateProgress() {
    if (!lessonSection || lessonSection.classList.contains('locked')) {
      if (progressBar) progressBar.style.width = '0%';
      return;
    }

    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;

    if (docHeight <= 0) {
      if (progressBar) progressBar.style.width = '100%';
      return;
    }

    const scrollPercent = Math.min(100, Math.max(0, (scrollTop / docHeight) * 100));
    if (progressBar) {
      progressBar.style.width = scrollPercent.toFixed(1) + '%';
    }
  }

  window.addEventListener('scroll', updateProgress);
  window.addEventListener('resize', updateProgress);
});
''';
  }
}
