import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_module_registry_service.dart';
import '../services/firebase_teacher_auth_service.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final FirebaseTeacherAuthService _authService = FirebaseTeacherAuthService.instance;
  late final FirebaseModuleRegistryService _registryService;

  List<RegisteredModule> _registeredModules = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _registryService = FirebaseModuleRegistryService(authService: _authService);
    _loadModules();
  }

  Future<void> _loadModules() async {
    if (!_authService.isSignedIn || !_authService.isAuthorizedTeacher) {
      setState(() {
        _registeredModules = [];
        _isLoading = false;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final modules = await _registryService.getRegisteredModules();
      if (!mounted) return;
      setState(() {
        _registeredModules = modules;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handleTogglePublish(RegisteredModule module) async {
    final newStatus = module.status == 'published' ? 'draft' : 'published';
    try {
      await _registryService.updateModuleStatus(module.moduleId, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Module status updated to "$newStatus".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadModules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: ${e.toString()}'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleOpenDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardUrl = prefs.getString('slm_teacher_dashboard_url') ?? '';

    if (dashboardUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure the Teacher Dashboard URL in Settings first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', dashboardUrl]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dashboardUrl]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dashboardUrl]);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch dashboard: ${e.toString()}'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSignedIn = _authService.isSignedIn && _authService.isAuthorizedTeacher;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'My Modules',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _handleOpenDashboard,
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Open Teacher Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadModules,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage and track all registered self-learning modules in Cloud Firestore.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (!isSignedIn) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined, size: 48, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'Firebase Teacher Account Required',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please sign in with your authorized Firebase Teacher Account in Settings to view and manage registered modules.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ] else if (_isLoading) ...[
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          ] else if (_errorMessage.isNotEmpty) ...[
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage, style: TextStyle(color: Colors.red.shade900))),
                  ],
                ),
              ),
            )
          ] else if (_registeredModules.isEmpty) ...[
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No registered modules found.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate and click [Register Module] in the Module Builder tab to register modules in Cloud Firestore.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ] else ...[
            Expanded(
              child: ListView.builder(
                itemCount: _registeredModules.length,
                itemBuilder: (context, index) {
                  final module = _registeredModules[index];
                  final isPublished = module.status == 'published';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  module.title,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${module.subject} • ${module.gradeLevel} • ${module.activityCount} Activities (${module.totalPoints} pts)',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  'ID: ${module.moduleId}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPublished ? Colors.green.shade100 : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              module.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPublished ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => _handleTogglePublish(module),
                            icon: Icon(isPublished ? Icons.unpublished_outlined : Icons.publish),
                            label: Text(isPublished ? 'Unpublish' : 'Publish'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
