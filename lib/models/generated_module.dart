import 'design_config.dart';

class GeneratedModule {
  final String moduleId;
  final String title;
  final String slug;
  final String html;
  final String css;
  final String javaScript;
  final String firebaseJavaScript;
  final DesignConfig designConfig;
  final DateTime generatedAt;
  final List<String> assets;

  const GeneratedModule({
    required this.moduleId,
    required this.title,
    required this.slug,
    required this.html,
    required this.css,
    required this.javaScript,
    required this.firebaseJavaScript,
    required this.designConfig,
    required this.generatedAt,
    this.assets = const [],
  });
}
