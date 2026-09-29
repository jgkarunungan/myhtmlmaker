enum DesignIntensity {
  conservative('Conservative'),
  balanced('Balanced'),
  creative('Creative');

  final String label;
  const DesignIntensity(this.label);
}

enum VisualProfile {
  auto('Auto'),
  modernAcademic('Modern Academic'),
  editorial('Editorial'),
  reflectiveJournal('Reflective Journal'),
  interactiveCards('Interactive Cards'),
  academicNotebook('Academic Notebook'),
  historicalDocumentary('Historical Documentary'),
  storytellingJourney('Storytelling Journey'),
  researchJournal('Research Journal'),
  infographic('Infographic'),
  minimalModern('Minimal Modern');

  final String label;
  const VisualProfile(this.label);
}

class DesignConfig {
  final VisualProfile visualProfile;
  final String designSeed;
  final DesignIntensity designIntensity;
  final String typography;
  final String layoutStyle;
  final String cardStyle;
  final String activityStyle;
  final String navigationStyle;
  final String sectionDividerStyle;
  final String backgroundTreatment;

  const DesignConfig({
    this.visualProfile = VisualProfile.auto,
    this.designSeed = '',
    this.designIntensity = DesignIntensity.balanced,
    this.typography = 'sans-serif',
    this.layoutStyle = 'standard',
    this.cardStyle = 'elevated',
    this.activityStyle = 'interactive',
    this.navigationStyle = 'top-bar',
    this.sectionDividerStyle = 'subtle',
    this.backgroundTreatment = 'clean',
  });

  DesignConfig copyWith({
    VisualProfile? visualProfile,
    String? designSeed,
    DesignIntensity? designIntensity,
    String? typography,
    String? layoutStyle,
    String? cardStyle,
    String? activityStyle,
    String? navigationStyle,
    String? sectionDividerStyle,
    String? backgroundTreatment,
  }) {
    return DesignConfig(
      visualProfile: visualProfile ?? this.visualProfile,
      designSeed: designSeed ?? this.designSeed,
      designIntensity: designIntensity ?? this.designIntensity,
      typography: typography ?? this.typography,
      layoutStyle: layoutStyle ?? this.layoutStyle,
      cardStyle: cardStyle ?? this.cardStyle,
      activityStyle: activityStyle ?? this.activityStyle,
      navigationStyle: navigationStyle ?? this.navigationStyle,
      sectionDividerStyle: sectionDividerStyle ?? this.sectionDividerStyle,
      backgroundTreatment: backgroundTreatment ?? this.backgroundTreatment,
    );
  }
}
