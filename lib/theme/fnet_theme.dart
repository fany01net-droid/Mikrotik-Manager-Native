import 'package:flutter/material.dart';

/// Official Standard Material 3 Theme for Mikrotik Manager
/// Conforming to https://docs.flutter.dev/ui/widgets/material
class FNetTheme {
  // Material 3 Seed Color Mikrotik
  static const Color seedColor = Color(0xFF00639B);

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
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    );
  }

  /// Official Standard Material 3 Dark Theme
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
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
