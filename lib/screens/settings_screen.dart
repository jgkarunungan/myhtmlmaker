import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ai_config.dart';
import '../config/student_config.dart';
import '../models/design_config.dart';
import '../services/ai_config_service.dart';
import '../services/ai_service.dart';
import '../services/firebase_teacher_auth_service.dart';
import '../services/grade_section_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _outputFolderController =
      TextEditingController(text: 'C:\\Users\\Teacher\\GeneratedModules');
  final TextEditingController _newSectionController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  final TextEditingController _teacherEmailController = TextEditingController();
  final TextEditingController _teacherPasswordController = TextEditingController();
  final TextEditingController _dashboardUrlController =
      TextEditingController(text: 'http://localhost:8080/teacher_dashboard/index.html');

  final GradeSectionService _gradeSectionService = GradeSectionService();
  final AiConfigService _aiConfigService = AiConfigService();
  final AIService _aiService = AIService();
  final FirebaseTeacherAuthService _teacherAuthService = FirebaseTeacherAuthService.instance;

  DesignIntensity _defaultIntensity = DesignIntensity.balanced;
  final String _selectedAiProvider = 'Google Gemini Developer API';

  String _selectedGradeLevel = 'Grade 7';
  late Map<String, List<String>> _gradeSectionsMap;
  bool _isTestingConnection = false;
  bool _obscureApiKey = true;
  bool _obscureTeacherPassword = true;
  bool _isSigningInTeacher = false;

  static const List<String> _gradeLevels = [
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  @override
  void initState() {
    super.initState();
    _gradeSectionsMap = Map.from(
      StudentConfig.gradeSectionsMap.map((k, v) => MapEntry(k, List<String>.from(v))),
    );

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final loadedMap = await _gradeSectionService.loadGradeSections();
    final loadedKey = await _aiConfigService.loadApiKey();
    final rememberedEmail = await _teacherAuthService.getRememberedEmail();

    final prefs = await SharedPreferences.getInstance();
    final savedDashboardUrl = prefs.getString('slm_teacher_dashboard_url') ?? '';
    if (savedDashboardUrl.isNotEmpty) {
      _dashboardUrlController.text = savedDashboardUrl;
    }

    if (!mounted) return;
    setState(() {
      _gradeSectionsMap = Map.from(loadedMap.map((k, v) => MapEntry(k, List<String>.from(v))));
      for (final gl in _gradeLevels) {
        _gradeSectionsMap.putIfAbsent(gl, () => []);
      }
      StudentConfig.updateGradeSections(_gradeSectionsMap);
      _apiKeyController.text = loadedKey;
      _teacherEmailController.text = rememberedEmail;
    });
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _outputFolderController.dispose();
    _newSectionController.dispose();
    _apiKeyController.dispose();
    _teacherEmailController.dispose();
    _teacherPasswordController.dispose();
    _dashboardUrlController.dispose();
    super.dispose();
  }

  void _addSection() {
    final text = _newSectionController.text.trim();
    if (text.isEmpty) return;

    final added = _gradeSectionService.addSection(_gradeSectionsMap, _selectedGradeLevel, text);
    if (added) {
      setState(() {
        _newSectionController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Section already exists or is invalid.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editSection(int index) {
    final currentSections = _gradeSectionsMap[_selectedGradeLevel] ?? [];
    if (index < 0 || index >= currentSections.length) return;

    final controller = TextEditingController(text: currentSections[index]);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Section Name ($_selectedGradeLevel)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Section Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = controller.text.trim();
                final edited = _gradeSectionService.editSection(
                  _gradeSectionsMap,
                  _selectedGradeLevel,
                  index,
                  newName,
                );
                if (edited) {
                  setState(() {});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Section already exists or is invalid.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteSection(int index) {
    final deleted = _gradeSectionService.deleteSection(_gradeSectionsMap, _selectedGradeLevel, index);
    if (deleted) {
      setState(() {});
    }
  }

  Future<void> _saveGradeSectionSetup() async {
    await _gradeSectionService.saveGradeSections(_gradeSectionsMap);
    StudentConfig.updateGradeSections(_gradeSectionsMap);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grade & Section setup saved successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleTestConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Gemini API Key first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    try {
      final success = await _aiService.testConnection(apiKeyOverride: key);
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
        if (success) {
          await _aiConfigService.saveApiKey(key);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected successfully! API Key verified and active for current session.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSaveApiKey() async {
    final key = _apiKeyController.text.trim();
    await _aiConfigService.saveApiKey(key);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gemini API Key set for current session.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleTeacherSignIn() async {
    setState(() {
      _isSigningInTeacher = true;
    });

    try {
      await _teacherAuthService.signInWithEmailAndPassword(
        email: _teacherEmailController.text,
        password: _teacherPasswordController.text,
      );
      _teacherPasswordController.clear();
      if (mounted) {
        setState(() {
          _isSigningInTeacher = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully as authorized teacher!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningInTeacher = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleTeacherSignOut() {
    _teacherAuthService.signOut();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed out of teacher account.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSaveDashboardUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('slm_teacher_dashboard_url', _dashboardUrlController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teacher Dashboard URL saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = _teacherAuthService.currentSession;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure application preferences, teacher authorization, export locations, and AI integration.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Firebase Teacher Account Section
          _buildSettingsSection(
            context: context,
            title: 'Firebase Teacher Account',
            icon: Icons.admin_panel_settings_outlined,
            children: session != null && session.isAuthorizedTeacher
                ? [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Signed in as: ${session.email}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            'Teacher UID: ${session.uid}',
                            style: TextStyle(fontSize: 0.85, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _handleTeacherSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
                  ]
                : [
                    TextField(
                      controller: _teacherEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Teacher Email',
                        hintText: 'teacher@school.edu',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _teacherPasswordController,
                      obscureText: _obscureTeacherPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureTeacherPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscureTeacherPassword = !_obscureTeacherPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isSigningInTeacher ? null : _handleTeacherSignIn,
                      icon: _isSigningInTeacher
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Sign In to Firebase'),
                    ),
                  ],
          ),

          const SizedBox(height: 20),

          // Universal Teacher Dashboard Configuration
          _buildSettingsSection(
            context: context,
            title: 'Universal Teacher Dashboard URL',
            icon: Icons.dashboard_outlined,
            children: [
              TextField(
                controller: _dashboardUrlController,
                decoration: const InputDecoration(
                  labelText: 'Teacher Dashboard URL',
                  hintText: 'http://localhost:8080/teacher_dashboard/index.html',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'URL of the Universal Teacher Dashboard application.',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _handleSaveDashboardUrl,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Dashboard URL'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Grade & Section Setup Section
          _buildSettingsSection(
            context: context,
            title: 'Grade & Section Setup',
            icon: Icons.school_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedGradeLevel,
                decoration: const InputDecoration(
                  labelText: 'Grade Level',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _gradeLevels.map((gl) {
                  return DropdownMenuItem<String>(
                    value: gl,
                    child: Text(gl),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedGradeLevel = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Sections for $_selectedGradeLevel:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSectionController,
                      decoration: const InputDecoration(
                        hintText: 'Section Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addSection(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ..._buildSectionList(context),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _saveGradeSectionSetup,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // AI Service Integration
          _buildSettingsSection(
            context: context,
            title: 'AI Service Integration (Gemini)',
            icon: Icons.smart_toy_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedAiProvider,
                decoration: const InputDecoration(
                  labelText: 'Selected AI Provider',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Configured model: ${AiConfig.modelName}',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Google Gemini Developer API',
                    child: Text('Google Gemini Developer API'),
                  ),
                ],
                onChanged: (val) {},
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'Enter API Key (AIzaSy...)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTestingConnection ? null : _handleTestConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt),
                    label: const Text('Test Connection'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _handleSaveApiKey,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save API Key'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Teacher Information
          _buildSettingsSection(
            context: context,
            title: 'Teacher Information',
            icon: Icons.person_outline,
            children: [
              TextField(
                controller: _teacherNameController,
                decoration: const InputDecoration(
                  labelText: 'Teacher Name',
                  hintText: 'e.g., Prof. Jane Doe',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Module Generation Preferences
          _buildSettingsSection(
            context: context,
            title: 'Module Generation Preferences',
            icon: Icons.palette_outlined,
            children: [
              Text(
                'Default Design Intensity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: DesignIntensity.values.map((intensity) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(intensity.label),
                      selected: _defaultIntensity == intensity,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _defaultIntensity = intensity;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _outputFolderController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Module Output Directory',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.folder_open),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionList(BuildContext context) {
    final sections = _gradeSectionsMap[_selectedGradeLevel] ?? [];
    if (sections.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'No sections added for $_selectedGradeLevel yet.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ];
    }

    return sections.asMap().entries.map((entry) {
      final index = entry.key;
      final name = entry.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _editSection(index),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _deleteSection(index),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSettingsSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
