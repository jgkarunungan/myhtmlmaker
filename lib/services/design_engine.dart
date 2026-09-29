import '../models/design_config.dart';

class ResolvedDesignProperties {
  final VisualProfile resolvedProfile;
  final DesignIntensity intensity;
  final String seed;
  final String primaryColor;
  final String primaryContainerColor;
  final String accentColor;
  final String backgroundColor;
  final String surfaceColor;
  final String textColor;
  final String textMutedColor;
  final String fontFamilyHeader;
  final String fontFamilyBody;
  final String borderRadius;
  final String boxShadow;
  final String heroStyle;
  final String cardTreatment;
  final String dividerStyle;
  final String spacingScale;

  const ResolvedDesignProperties({
    required this.resolvedProfile,
    required this.intensity,
    required this.seed,
    required this.primaryColor,
    required this.primaryContainerColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
    required this.textMutedColor,
    required this.fontFamilyHeader,
    required this.fontFamilyBody,
    required this.borderRadius,
    required this.boxShadow,
    required this.heroStyle,
    required this.cardTreatment,
    required this.dividerStyle,
    required this.spacingScale,
  });
}

/// Deterministic design engine mapping a [DesignConfig] and seed into concrete
/// presentation tokens (colors, typography, hero layouts, card treatments).
class DesignEngine {
  static const List<VisualProfile> _supportedProfiles = [
    VisualProfile.modernAcademic,
    VisualProfile.editorial,
    VisualProfile.reflectiveJournal,
    VisualProfile.interactiveCards,
  ];

  static ResolvedDesignProperties resolve(DesignConfig config) {
    final String seedStr = config.designSeed.isEmpty ? 'default-seed' : config.designSeed;
    final int seedHash = seedStr.hashCode.abs();

    // Resolve Visual Profile
    final VisualProfile profile = (config.visualProfile == VisualProfile.auto)
        ? _supportedProfiles[seedHash % _supportedProfiles.length]
        : config.visualProfile;

    // Resolve Intensity Tokens
    final intensity = config.designIntensity;
    final String borderRadius = switch (intensity) {
      DesignIntensity.conservative => '4px',
      DesignIntensity.balanced => '12px',
      DesignIntensity.creative => '20px',
    };

    final String boxShadow = switch (intensity) {
      DesignIntensity.conservative => '0 1px 3px rgba(0,0,0,0.06)',
      DesignIntensity.balanced => '0 4px 16px rgba(0,0,0,0.08)',
      DesignIntensity.creative => '0 10px 30px rgba(0,0,0,0.12)',
    };

    final String spacingScale = switch (intensity) {
      DesignIntensity.conservative => '1.2rem',
      DesignIntensity.balanced => '1.8rem',
      DesignIntensity.creative => '2.4rem',
    };

    // Deterministic palette selection based on profile + seed
    final int paletteVariant = (seedHash ~/ 7) % 3;

    String primaryColor;
    String primaryContainerColor;
    String accentColor;
    String backgroundColor;
    String surfaceColor;
    String textColor;
    String textMutedColor;
    String fontHeader;
    String fontBody;

    switch (profile) {
      case VisualProfile.modernAcademic:
        fontHeader = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
        fontBody = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
        backgroundColor = '#F8FAFC';
        surfaceColor = '#FFFFFF';
        textColor = '#0F172A';
        textMutedColor = '#475569';
        if (paletteVariant == 0) {
          primaryColor = '#1E40AF'; // Deep Academic Blue
          primaryContainerColor = '#EFF6FF';
          accentColor = '#0284C7';
        } else if (paletteVariant == 1) {
          primaryColor = '#0F766E'; // Teal Academic
          primaryContainerColor = '#F0FDF4';
          accentColor = '#2563EB';
        } else {
          primaryColor = '#3730A3'; // Indigo Academic
          primaryContainerColor = '#EEF2FF';
          accentColor = '#0D9488';
        }
        break;

      case VisualProfile.editorial:
        fontHeader = 'Georgia, "Times New Roman", Times, serif';
        fontBody = 'Georgia, serif';
        backgroundColor = '#FAF9F6';
        surfaceColor = '#FFFFFF';
        textColor = '#1C1917';
        textMutedColor = '#57534E';
        if (paletteVariant == 0) {
          primaryColor = '#78350F'; // Warm Mahogany
          primaryContainerColor = '#FEF3C7';
          accentColor = '#B45309';
        } else if (paletteVariant == 1) {
          primaryColor = '#881337'; // Wine Editorial
          primaryContainerColor = '#FFF1F2';
          accentColor = '#D97706';
        } else {
          primaryColor = '#1E293B'; // Slate Editorial
          primaryContainerColor = '#F1F5F9';
          accentColor = '#C2410C';
        }
        break;

      case VisualProfile.reflectiveJournal:
        fontHeader = '"Garamond", "Georgia", Cambria, serif';
        fontBody = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
        backgroundColor = '#F5F7F4';
        surfaceColor = '#FFFFFF';
        textColor = '#1E2923';
        textMutedColor = '#4A5D52';
        if (paletteVariant == 0) {
          primaryColor = '#2D5A27'; // Forest Sage
          primaryContainerColor = '#F0F7EF';
          accentColor = '#C2410C';
        } else if (paletteVariant == 1) {
          primaryColor = '#164E63'; // Ocean Reflection
          primaryContainerColor = '#ECFEFF';
          accentColor = '#059669';
        } else {
          primaryColor = '#4C1D95'; // Deep Reflection
          primaryContainerColor = '#F5F3FF';
          accentColor = '#D97706';
        }
        break;

      case VisualProfile.interactiveCards:
      default:
        fontHeader = 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
        fontBody = 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
        backgroundColor = '#F3F4F6';
        surfaceColor = '#FFFFFF';
        textColor = '#111827';
        textMutedColor = '#4B5563';
        if (paletteVariant == 0) {
          primaryColor = '#4F46E5'; // Modern Indigo
          primaryContainerColor = '#EEF2FF';
          accentColor = '#10B981';
        } else if (paletteVariant == 1) {
          primaryColor = '#2563EB'; // Vibrant Blue
          primaryContainerColor = '#EFF6FF';
          accentColor = '#8B5CF6';
        } else {
          primaryColor = '#7C3AED'; // Electric Purple
          primaryContainerColor = '#F5F3FF';
          accentColor = '#06B6D4';
        }
        break;
    }

    // Hero style & layout variations
    final heroVariants = ['banner-hero', 'card-hero', 'centered-hero', 'accent-left-hero'];
    final heroStyle = heroVariants[(seedHash ~/ 3) % heroVariants.length];

    final cardVariants = ['elevated-card', 'bordered-card', 'top-accent-card', 'minimal-card'];
    final cardTreatment = cardVariants[(seedHash ~/ 5) % cardVariants.length];

    final dividerVariants = ['solid-line', 'accent-pill', 'gradient-strip', 'subtle-space'];
    final dividerStyle = dividerVariants[(seedHash ~/ 11) % dividerVariants.length];

    return ResolvedDesignProperties(
      resolvedProfile: profile,
      intensity: intensity,
      seed: seedStr,
      primaryColor: primaryColor,
      primaryContainerColor: primaryContainerColor,
      accentColor: accentColor,
      backgroundColor: backgroundColor,
      surfaceColor: surfaceColor,
      textColor: textColor,
      textMutedColor: textMutedColor,
      fontFamilyHeader: fontHeader,
      fontFamilyBody: fontBody,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      heroStyle: heroStyle,
      cardTreatment: cardTreatment,
      dividerStyle: dividerStyle,
      spacingScale: spacingScale,
    );
  }
}
