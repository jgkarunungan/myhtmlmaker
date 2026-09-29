import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/student_config.dart';
import '../models/design_config.dart';
import '../models/generated_module.dart';
import '../models/lesson_analysis.dart';
import '../models/lesson_model.dart';
import '../services/ai_service.dart';
import '../services/firebase_module_registry_service.dart';
import '../services/firebase_teacher_auth_service.dart';
import '../services/html_generator_service.dart';
import '../services/module_export_service.dart';
import '../utils/module_id_generator.dart';
import '../widgets/analysis_review_panel.dart';
import '../widgets/lesson_editor.dart';
import '../widgets/lesson_setup_panel.dart';
import '../widgets/preview_panel.dart';

class ModuleBuilderScreen extends StatefulWidget {
  const ModuleBuilderScreen({super.key});

  @override
  State<ModuleBuilderScreen> createState() => _ModuleBuilderScreenState();
}

class _ModuleBuilderScreenState extends State<ModuleBuilderScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _lessonTextController = TextEditingController();

  final HtmlGeneratorService _generatorService = HtmlGeneratorService();
  final ModuleExportService _exportService = ModuleExportService();
  final AIService _aiService = AIService();
  final FirebaseTeacherAuthService _teacherAuthService = FirebaseTeacherAuthService.instance;
  late final FirebaseModuleRegistryService _registryService;

  String _selectedGrade = StudentConfig.allowedGradeLevels.first;
  VisualProfile _selectedProfile = VisualProfile.auto;
  DesignIntensity _selectedIntensity = DesignIntensity.balanced;
  String _currentSeed = '';

  LessonModel? _currentLesson;
  GeneratedModule? _generatedModule;
  bool _isGenerating = false;
  bool _isAnalyzing = false;
  bool _isRegistering = false;
  String _lastAnalyzedRawText = '';

  @override
  void initState() {
    super.initState();
    _registryService = FirebaseModuleRegistryService(authService: _teacherAuthService);
    _lessonTextController.addListener(_onLessonTextEdited);
  }

  @override
  void dispose() {
    _lessonTextController.removeListener(_onLessonTextEdited);
    _titleController.dispose();
    _subjectController.dispose();
    _lessonTextController.dispose();
    super.dispose();
  }

  void _onLessonTextEdited() {
    final currentText = _lessonTextController.text;
    if (_currentLesson != null &&
        _currentLesson!.hasStructuredAnalysis &&
        currentText != _lastAnalyzedRawText) {
      if (_currentLesson!.analysis?.status != AnalysisStatus.outdated) {
        setState(() {
          _currentLesson = _currentLesson!.copyWith(
            analysis: _currentLesson!.analysis?.copyWith(
              status: AnalysisStatus.outdated,
            ),
          );
        });
      }
    }
  }

  void _showSnackBar(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade800 : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleCreateNewModule() {
    setState(() {
      _titleController.clear();
      _subjectController.clear();
      _lessonTextController.clear();
      _currentLesson = LessonModel(id: ModuleIdGenerator.generate());
      _generatedModule = null;
      _lastAnalyzedRawText = '';
      _currentSeed = '';
    });
    _showSnackBar('Created a new module session.');
  }

  Future<void> _handleAnalyzeLesson() async {
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final lessonText = _lessonTextController.text.trim();

    if (subject.isEmpty) {
      _showSnackBar('Please enter a Subject before analyzing.', isError: true);
      return;
    }
    if (lessonText.isEmpty) {
      _showSnackBar('Please enter lesson content before analyzing.', isError: true);
      return;
    }
    if (!_aiService.hasApiKey) {
      _showSnackBar('Gemini API Key is not configured. Please enter your key in Settings.', isError: true);
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final baseLesson = LessonModel(
        id: _currentLesson?.id ?? ModuleIdGenerator.generate(),
        title: title,
        subject: subject,
        gradeLevel: _selectedGrade,
        rawLessonText: lessonText,
      );

      final analyzedLesson = await _aiService.analyzeLesson(currentLesson: baseLesson);

      if (_selectedProfile == VisualProfile.auto &&
          analyzedLesson.analysis?.recommendation.suggestedProfile != VisualProfile.auto) {
        _selectedProfile = analyzedLesson.analysis!.recommendation.suggestedProfile;
      }

      if (_titleController.text.trim().isEmpty && analyzedLesson.title.isNotEmpty) {
        _titleController.text = analyzedLesson.title;
      }

      setState(() {
        _currentLesson = analyzedLesson;
        _lastAnalyzedRawText = lessonText;
        _isAnalyzing = false;
      });

      _showSnackBar('Lesson analyzed successfully! Review structured data below.');
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      _showSnackBar('Gemini Analysis Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _handleGenerateModule({bool forceNewSeed = false}) async {
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final lessonText = _lessonTextController.text.trim();

    if (title.isEmpty) {
      _showSnackBar('Please enter a Module Title before generating.', isError: true);
      return;
    }
    if (subject.isEmpty) {
      _showSnackBar('Please enter a Subject before generating.', isError: true);
      return;
    }
    if (lessonText.isEmpty) {
      _showSnackBar('Please paste or enter lesson content before generating.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      if (_currentSeed.isEmpty || forceNewSeed) {
        _currentSeed = DateTime.now().millisecondsSinceEpoch.toString();
      }

      final lessonToUse = (_currentLesson != null)
          ? _currentLesson!.copyWith(
              title: title,
              subject: subject,
              gradeLevel: _selectedGrade,
              rawLessonText: lessonText,
            )
          : LessonModel(
              id: ModuleIdGenerator.generate(),
              title: title,
              subject: subject,
              gradeLevel: _selectedGrade,
              rawLessonText: lessonText,
            );

      final designConfig = DesignConfig(
        visualProfile: _selectedProfile,
        designIntensity: _selectedIntensity,
        designSeed: _currentSeed,
      );

      final module = await _generatorService.generateModule(
        lesson: lessonToUse,
        designConfig: designConfig,
      );

      setState(() {
        _currentLesson = lessonToUse;
        _generatedModule = module;
        _isGenerating = false;
      });

      _showSnackBar(
        forceNewSeed
            ? 'Design regenerated with new seed: $_currentSeed'
            : 'Module generated successfully!',
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showSnackBar('Failed to generate module: ${e.toString()}', isError: true);
    }
  }

  Future<void> _handleRegisterModule({String status = 'draft'}) async {
    if (!_teacherAuthService.isSignedIn || !_teacherAuthService.isAuthorizedTeacher) {
      _showSnackBar('Sign in to your Firebase teacher account in Settings before registering this module.', isError: true);
      return;
    }
    if (_generatedModule == null || _currentLesson == null) {
      _showSnackBar('Please generate a module first before registering.', isError: true);
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      await _registryService.registerModule(
        lesson: _currentLesson!,
        designConfig: _generatedModule!.designConfig,
        status: status,
      );

      setState(() {
        _isRegistering = false;
      });

      _showSnackBar(
        status == 'published'
            ? 'Module registered and PUBLISHED in Firebase!'
            : 'Module registered successfully as DRAFT in Firebase!',
      );
    } catch (e) {
      setState(() {
        _isRegistering = false;
      });
      _showSnackBar('Module was generated successfully but could not be registered in Firebase: ${e.toString()}', isError: true);
    }
  }

  Future<void> _handleRegenerateDesign() async {
    if (_generatedModule == null) {
      _showSnackBar('Please generate a module first.', isError: true);
      return;
    }
    await _handleGenerateModule(forceNewSeed: true);
  }

  Future<void> _handlePreviewInBrowser() async {
    if (_generatedModule == null) {
      _showSnackBar('No generated module to preview.', isError: true);
      return;
    }

    final result = await _exportService.launchBrowserPreview(module: _generatedModule!);
    if (result.isSuccess) {
      _showSnackBar('Opened module in default browser.');
    } else {
      _showSnackBar(result.errorMessage ?? 'Failed to launch browser.', isError: true);
    }
  }

  Future<void> _handleExportModule() async {
    if (_generatedModule == null) {
      _showSnackBar('No generated module to export.', isError: true);
      return;
    }

    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Destination Folder',
      );

      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        return;
      }

      final result = await _exportService.exportModule(
        module: _generatedModule!,
        parentDirectoryPath: selectedDirectory,
      );

      if (result.isSuccess) {
        _showSnackBar('Exported standalone module to:\n${result.exportedPath}');
      } else {
        _showSnackBar(result.errorMessage ?? 'Export failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Directory selection error: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideDesktop = constraints.maxWidth >= 700;

          final previewWidget = PreviewPanel(
            generatedModule: _generatedModule,
            isGenerating: _isGenerating,
            onPreviewInBrowser: _handlePreviewInBrowser,
            onRegenerateDesign: _handleRegenerateDesign,
            onExportModule: _handleExportModule,
          );

          if (isWideDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LessonSetupPanel(
                          titleController: _titleController,
                          subjectController: _subjectController,
                          selectedGrade: _selectedGrade,
                          selectedProfile: _selectedProfile,
                          selectedIntensity: _selectedIntensity,
                          onGradeChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedGrade = val;
                              });
                            }
                          },
                          onProfileChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedProfile = val;
                              });
                            }
                          },
                          onIntensityChanged: (intensity) {
                            setState(() {
                              _selectedIntensity = intensity;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        LessonEditor(
                          controller: _lessonTextController,
                        ),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        if (_currentLesson != null && _currentLesson!.hasStructuredAnalysis) ...[
                          const SizedBox(height: 16),
                          AnalysisReviewPanel(
                            lesson: _currentLesson!,
                            onLessonChanged: (updated) {
                              setState(() {
                                _currentLesson = updated;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  flex: 5,
                  child: previewWidget,
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LessonSetupPanel(
                    titleController: _titleController,
                    subjectController: _subjectController,
                    selectedGrade: _selectedGrade,
                    selectedProfile: _selectedProfile,
                    selectedIntensity: _selectedIntensity,
                    onGradeChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGrade = val;
                        });
                      }
                    },
                    onProfileChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProfile = val;
                        });
                      }
                    },
                    onIntensityChanged: (intensity) {
                      setState(() {
                        _selectedIntensity = intensity;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  LessonEditor(
                    controller: _lessonTextController,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  if (_currentLesson != null && _currentLesson!.hasStructuredAnalysis) ...[
                    const SizedBox(height: 16),
                    AnalysisReviewPanel(
                      lesson: _currentLesson!,
                      onLessonChanged: (updated) {
                        setState(() {
                          _currentLesson = updated;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 550,
                    child: previewWidget,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasGenerated = _generatedModule != null;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        TextButton.icon(
          onPressed: _handleCreateNewModule,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Create New Module'),
        ),
        OutlinedButton.icon(
          onPressed: _isAnalyzing ? null : _handleAnalyzeLesson,
          icon: _isAnalyzing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Lesson'),
        ),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : () => _handleGenerateModule(),
          icon: _isGenerating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.build_circle_outlined),
          label: const Text('Generate Module'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        if (hasGenerated) ...[
          OutlinedButton.icon(
            onPressed: _isRegistering ? null : () => _handleRegisterModule(status: 'draft'),
            icon: _isRegistering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Register Module'),
          ),
          ElevatedButton.icon(
            onPressed: _isRegistering ? null : () => _handleRegisterModule(status: 'published'),
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publish Module'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}
