import 'dart:io';

import '../models/generated_module.dart';
import '../utils/slug_utils.dart';

class ExportResult {
  final bool isSuccess;
  final String exportedPath;
  final String? errorMessage;

  const ExportResult({
    required this.isSuccess,
    required this.exportedPath,
    this.errorMessage,
  });
}

/// Service managing file exports and temporary browser preview generation.
class ModuleExportService {
  /// Launches [module] in the user's default browser using a temporary directory.
  Future<ExportResult> launchBrowserPreview({
    required GeneratedModule module,
  }) async {
    try {
      final Directory tempDir = Directory.systemTemp.createTempSync('slm_preview_');
      final Directory cssDir = Directory('${tempDir.path}${Platform.pathSeparator}css');
      final Directory jsDir = Directory('${tempDir.path}${Platform.pathSeparator}js');

      await cssDir.create(recursive: true);
      await jsDir.create(recursive: true);

      final File htmlFile = File('${tempDir.path}${Platform.pathSeparator}index.html');
      final File cssFile = File('${cssDir.path}${Platform.pathSeparator}module.css');
      final File jsFile = File('${jsDir.path}${Platform.pathSeparator}module.js');
      final File firebaseJsFile = File('${jsDir.path}${Platform.pathSeparator}firebase.js');

      await htmlFile.writeAsString(module.html);
      await cssFile.writeAsString(module.css);
      await jsFile.writeAsString(module.javaScript);
      await firebaseJsFile.writeAsString(module.firebaseJavaScript);

      final String htmlPath = htmlFile.path;

      if (Platform.isWindows) {
        // Launch using default Windows application/browser
        await Process.run('cmd', ['/c', 'start', '', htmlPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [htmlPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [htmlPath]);
      } else {
        return ExportResult(
          isSuccess: false,
          exportedPath: htmlPath,
          errorMessage: 'Browser preview not supported on this platform.',
        );
      }

      return ExportResult(
        isSuccess: true,
        exportedPath: htmlPath,
      );
    } catch (e) {
      return ExportResult(
        isSuccess: false,
        exportedPath: '',
        errorMessage: 'Failed to launch browser preview: ${e.toString()}',
      );
    }
  }

  /// Exports [module] into a self-contained directory under [parentDirectoryPath].
  /// Handles slug collision by suffixing `-2`, `-3`, etc.
  Future<ExportResult> exportModule({
    required GeneratedModule module,
    required String parentDirectoryPath,
  }) async {
    try {
      final Directory parentDir = Directory(parentDirectoryPath);
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final String baseSlug = module.slug.isEmpty
          ? SlugUtils.generateSlug(module.title)
          : module.slug;

      final String finalSlug = SlugUtils.resolveCollision(
        baseSlug: baseSlug,
        existsCheck: (candidate) {
          final candidatePath = '${parentDir.path}${Platform.pathSeparator}$candidate';
          return Directory(candidatePath).existsSync();
        },
      );

      final String targetPath = '${parentDir.path}${Platform.pathSeparator}$finalSlug';
      final Directory targetDir = Directory(targetPath);
      final Directory cssDir = Directory('$targetPath${Platform.pathSeparator}css');
      final Directory jsDir = Directory('$targetPath${Platform.pathSeparator}js');

      await cssDir.create(recursive: true);
      await jsDir.create(recursive: true);

      final File htmlFile = File('$targetPath${Platform.pathSeparator}index.html');
      final File cssFile = File('${cssDir.path}${Platform.pathSeparator}module.css');
      final File jsFile = File('${jsDir.path}${Platform.pathSeparator}module.js');
      final File firebaseJsFile = File('${jsDir.path}${Platform.pathSeparator}firebase.js');

      await htmlFile.writeAsString(module.html);
      await cssFile.writeAsString(module.css);
      await jsFile.writeAsString(module.javaScript);
      await firebaseJsFile.writeAsString(module.firebaseJavaScript);

      return ExportResult(
        isSuccess: true,
        exportedPath: targetDir.path,
      );
    } catch (e) {
      return ExportResult(
        isSuccess: false,
        exportedPath: '',
        errorMessage: 'Export failed: ${e.toString()}',
      );
    }
  }
}
