/// Centralized dimension constants — replace magic numbers across the codebase.
abstract final class AppDimensions {
  // ── Cover art sizes ──
  static const double coverSmall = 40;
  static const double coverMedium = 52;
  static const double coverList = 44;
  static const double coverAlbumRow = 130;
  static const double coverAlbumDetail = 200;
  static const double coverAlbumDetailDesktop = 240;
  static const double coverPlayerMobile = 300;
  static const double coverPlayerDesktop = 360;
  static const double coverArtist = 128; // CircleAvatar diameter

  // ── Grid / list ──
  static const double albumRowHeight = 180;
  static const double dailyGridAspectRatio = 4.0;
  static const double albumGridMaxExtent = 220;
  static const double playlistCardWidth = 260;

  // ── Layout regions ──
  static const double sidebarWidth = 200;
  static const double queuePanelWidth = 320;
  static const double miniPlayerHeightMobile = 52;
  static const double miniPlayerHeightDesktop = 72;
  static const double lyricsLineHeight = 44;

  // ── Card / container ──
  static const double cardRadius = 12;
  static const double cardRadiusSmall = 8;
  static const double iconBoxSize = 40;
  static const double iconBoxRadius = 10;

  // ── Spacing ──
  static const double paddingMobile = 16;
  static const double paddingDesktop = 32;
  static const double sectionGap = 24;
  static const double itemGap = 12;

  // ── Volume ──
  static const double volumeSliderWidth = 100;
}

/// Responsive breakpoints — three-tier system.
abstract final class AppBreakpoints {
  /// Phone portrait
  static const double compact = 600;

  /// Tablet / half-screen
  static const double medium = 900;

  /// Desktop / wide
  static const double expanded = 1200;

  /// Convenience: returns true when width < [compact].
  static bool isMobile(double width) => width < compact;

  /// Convenience: returns true when width >= [compact] and < [medium].
  static bool isMedium(double width) => width >= compact && width < medium;

  /// Convenience: returns true when width >= [compact] (any desktop-ish).
  static bool isDesktop(double width) => width >= compact;
}
