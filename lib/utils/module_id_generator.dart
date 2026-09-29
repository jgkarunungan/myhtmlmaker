import 'dart:math';

/// Utility generating high-entropy secure identifiers for modules.
class ModuleIdGenerator {
  static final Random _random = Random.secure();

  /// Generates a high-entropy stable identifier such as `mod_8f3a11d29c6e47ab0123456789abcdef`.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final hexString = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'mod_$hexString';
  }
}
