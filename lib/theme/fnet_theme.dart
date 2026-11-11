import 'package:flutter/material.dart';

/// Official Standard Material 3 Palette Definition
class FNetThemePalette {
  final String key;
  final String name;
  final String description;
  final Color seedColor;

  const FNetThemePalette({
    required this.key,
    required this.name,
    required this.description,
    required this.seedColor,
  });
}

/// Official Standard Material 3 Theme for Mikrotik Manager
/// Conforming to https://docs.flutter.dev/ui/widgets/material
class FNetTheme {
  // Material 3 Seed Color Mikrotik (Default)
  static const Color seedColor = Color(0xFF00639B);

  // Available Curated Material 3 Color Palettes
  static const List<FNetThemePalette> palettes = [
    FNetThemePalette(
      key: 'blue',
      name: 'MikroTik Blue',
      description: 'Biru klasik bawaan MikroTik (Default)',
      seedColor: Color(0xFF00639B),
    ),
    FNetThemePalette(
      key: 'emerald',
      name: 'Emerald Green',
      description: 'Hijau emerald segar & natural',
      seedColor: Color(0xFF059669),
    ),
    FNetThemePalette(
      key: 'teal',
      name: 'Teal Cyan',
      description: 'Cyan modern berkarakter sejuk',
      seedColor: Color(0xFF0D9488),
    ),
    FNetThemePalette(
      key: 'indigo',
      name: 'Royal Indigo',
      description: 'Indigo elegan dan profesional',
      seedColor: Color(0xFF4F46E5),
    ),
    FNetThemePalette(
      key: 'purple',
      name: 'Deep Purple',
      description: 'Ungu violet khas Material 3',
      seedColor: Color(0xFF7C3AED),
    ),
    FNetThemePalette(
      key: 'crimson',
      name: 'Ruby Crimson',
      description: 'Merah ruby tegas dan kontras',
      seedColor: Color(0xFFE11D48),
    ),
    FNetThemePalette(
      key: 'amber',
      name: 'Sunset Amber',
      description: 'Jingga keemasan hangat',
      seedColor: Color(0xFFD97706),
    ),
  ];

  static Color getSeedColor(String key) {
    return palettes.firstWhere(
      (p) => p.key == key,
      orElse: () => palettes.first,
    ).seedColor;
  }

  static FNetThemePalette getPalette(String key) {
    return palettes.firstWhere(
      (p) => p.key == key,
      orElse: () => palettes.first,
    );
  }

  // Standard Network Status Colors
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFEF4444);
  static const Color sky = Color(0xFF0284C7);

  static Color latencyColor(int ms) {
    if (ms <= 0) return Colors.grey;
    if (ms < 500) return emerald;
    if (ms <= 2000) return amber;
    return rose;
  }

  /// Official Standard Material 3 Light Theme
  static ThemeData lightTheme([Color? customSeed]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: customSeed ?? seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        closeIconColor: colorScheme.onSurfaceVariant,
        actionTextColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        selectedColor: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Official Standard Material 3 Dark Theme
  static ThemeData darkTheme([Color? customSeed]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: customSeed ?? seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        closeIconColor: colorScheme.onSurfaceVariant,
        actionTextColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        selectedColor: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Standard Monospace Style for Networking Telemetry (IP, MAC, Latency, Bandwidth)
  static TextStyle monoStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
