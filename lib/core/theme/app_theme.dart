import 'package:flutter/material.dart';
import '../../domain/entities/screenshot_entity.dart';

/// Single place defining the app's visual identity: a vivid indigo/violet seed,
/// soft rounded surfaces, and one consistent color per screenshot status so the
/// same meaning ("scheduled", "kept", ...) reads the same everywhere it appears.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF6153F5);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      textTheme: const TextTheme().apply(fontFamily: null),
    );
  }
}

/// Consistent color + icon per status, independent of light/dark theme so a
/// "scheduled" chip always reads as amber, "kept" always reads as green, etc.
class StatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const StatusStyle(this.color, this.icon, this.label);

  static StatusStyle of(ScreenshotStatus status) {
    switch (status) {
      case ScreenshotStatus.pendingChoice:
        return const StatusStyle(Color(0xFF6366F1), Icons.hourglass_top_rounded, 'Awaiting choice');
      case ScreenshotStatus.scheduled:
        return const StatusStyle(Color(0xFFF59E0B), Icons.timer_rounded, 'Scheduled');
      case ScreenshotStatus.kept:
        return const StatusStyle(Color(0xFF10B981), Icons.check_circle_rounded, 'Kept');
      case ScreenshotStatus.deleted:
        return const StatusStyle(Color(0xFF94A3B8), Icons.delete_rounded, 'Deleted');
      case ScreenshotStatus.needsConfirmation:
        return const StatusStyle(Color(0xFFEF4444), Icons.warning_rounded, 'Needs attention');
    }
  }
}
