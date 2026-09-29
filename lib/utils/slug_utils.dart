/// Utility for generating safe filesystem slugs from module titles.
class SlugUtils {
  /// Generates a safe URL and directory slug from a raw string.
  static String generateSlug(String input) {
    if (input.trim().isEmpty) {
      return 'module';
    }

    String slug = input.trim().toLowerCase();

    // Replace non-alphanumeric characters with hyphens
    slug = slug.replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    // Remove leading and trailing hyphens
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');

    // Collapse multiple consecutive hyphens
    slug = slug.replaceAll(RegExp(r'-+'), '-');

    return slug.isEmpty ? 'module' : slug;
  }

  /// Generates a collision-free directory slug name if a directory already exists.
  ///
  /// Example: 'prudence' -> 'prudence-2' -> 'prudence-3'
  static String resolveCollision({
    required String baseSlug,
    required bool Function(String candidate) existsCheck,
  }) {
    if (!existsCheck(baseSlug)) {
      return baseSlug;
    }

    int counter = 2;
    while (true) {
      final candidate = '$baseSlug-$counter';
      if (!existsCheck(candidate)) {
        return candidate;
      }
      counter++;
    }
  }
}
