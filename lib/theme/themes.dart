import 'package:flutter/material.dart';

// Utility to convert a hex string to a Color object
Color _colorFromHex(String hex) {
  // Handles both #RRGGBB and #AARRGGBB formats
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class AppTheme {
  final String name;
  final List<Color> gradientColors;
  final ColorScheme light;
  final ColorScheme lightMediumContrast;
  final ColorScheme lightHighContrast;
  final ColorScheme dark;
  final ColorScheme darkMediumContrast;
  final ColorScheme darkHighContrast;

  AppTheme({
    required this.name,
    required this.gradientColors,
    required this.light,
    required this.lightMediumContrast,
    required this.lightHighContrast,
    required this.dark,
    required this.darkMediumContrast,
    required this.darkHighContrast,
  });

  // Create an AppTheme from JSON
  factory AppTheme.fromJson(Map<String, dynamic> json) {
    // Helper for parsing a ColorScheme from JSON
    ColorScheme colorSchemeFromJson(Map<String, dynamic> schemeJson, bool light) {
      return ColorScheme(
        brightness: light ? Brightness.light : Brightness.dark,
        primary: _colorFromHex(schemeJson['primary']),
        surfaceTint: _colorFromHex(schemeJson['surfaceTint']),
        onPrimary: _colorFromHex(schemeJson['onPrimary']),
        primaryContainer: _colorFromHex(schemeJson['primaryContainer']),
        onPrimaryContainer: _colorFromHex(schemeJson['onPrimaryContainer']),
        secondary: _colorFromHex(schemeJson['secondary']),
        onSecondary: _colorFromHex(schemeJson['onSecondary']),
        secondaryContainer: _colorFromHex(schemeJson['secondaryContainer']),
        onSecondaryContainer: _colorFromHex(schemeJson['onSecondaryContainer']),
        tertiary: _colorFromHex(schemeJson['tertiary']),
        onTertiary: _colorFromHex(schemeJson['onTertiary']),
        tertiaryContainer: _colorFromHex(schemeJson['tertiaryContainer']),
        onTertiaryContainer: _colorFromHex(schemeJson['onTertiaryContainer']),
        error: _colorFromHex(schemeJson['error']),
        onError: _colorFromHex(schemeJson['onError']),
        errorContainer: _colorFromHex(schemeJson['errorContainer']),
        onErrorContainer: _colorFromHex(schemeJson['onErrorContainer']),
        surface: _colorFromHex(schemeJson['surface']),
        onSurface: _colorFromHex(schemeJson['onSurface']),
        onSurfaceVariant: _colorFromHex(schemeJson['onSurfaceVariant']),
        outline: _colorFromHex(schemeJson['outline']),
        outlineVariant: _colorFromHex(schemeJson['outlineVariant']),
        shadow: _colorFromHex(schemeJson['shadow']),
        scrim: _colorFromHex(schemeJson['scrim']),
        inverseSurface: _colorFromHex(schemeJson['inverseSurface']),
        inversePrimary: _colorFromHex(schemeJson['inversePrimary']),
        primaryFixed: _colorFromHex(schemeJson['primaryFixed']),
        onPrimaryFixed: _colorFromHex(schemeJson['onPrimaryFixed']),
        primaryFixedDim: _colorFromHex(schemeJson['primaryFixedDim']),
        onPrimaryFixedVariant: _colorFromHex(schemeJson['onPrimaryFixedVariant']),
        secondaryFixed: _colorFromHex(schemeJson['secondaryFixed']),
        onSecondaryFixed: _colorFromHex(schemeJson['onSecondaryFixed']),
        secondaryFixedDim: _colorFromHex(schemeJson['secondaryFixedDim']),
        onSecondaryFixedVariant: _colorFromHex(schemeJson['onSecondaryFixedVariant']),
        tertiaryFixed: _colorFromHex(schemeJson['tertiaryFixed']),
        onTertiaryFixed: _colorFromHex(schemeJson['onTertiaryFixed']),
        tertiaryFixedDim: _colorFromHex(schemeJson['tertiaryFixedDim']),
        onTertiaryFixedVariant: _colorFromHex(schemeJson['onTertiaryFixedVariant']),
        surfaceDim: _colorFromHex(schemeJson['surfaceDim']),
        surfaceBright: _colorFromHex(schemeJson['surfaceBright']),
        surfaceContainerLowest: _colorFromHex(schemeJson['surfaceContainerLowest']),
        surfaceContainerLow: _colorFromHex(schemeJson['surfaceContainerLow']),
        surfaceContainer: _colorFromHex(schemeJson['surfaceContainer']),
        surfaceContainerHigh: _colorFromHex(schemeJson['surfaceContainerHigh']),
        surfaceContainerHighest: _colorFromHex(schemeJson['surfaceContainerHighest']),
      );
    }

    final schemes = json['schemes'] as Map<String, dynamic>;

    // Parse gradient colors, with a fallback
    final List<Color> gradient =
        (json['gradientColors'] as List<dynamic>?)
            ?.map((hex) => _colorFromHex(hex as String))
            .toList() ??
        [const Color(0xFF4285F4), const Color(0xFF9B72CB)];

    // --- FIX: Robustly handle potentially empty or missing contrast schemes ---
    // 1. Define base schemes
    final lightBase = schemes['light'] as Map<String, dynamic>;
    final darkBase = schemes['dark'] as Map<String, dynamic>;

    // 2. Create merged schemes that start with the base and add any contrast-specific overrides
    final lightMediumContrast = Map<String, dynamic>.from(lightBase)
      ..addAll(schemes['light-medium-contrast'] as Map<String, dynamic>? ?? {});

    final lightHighContrast = Map<String, dynamic>.from(lightBase)
      ..addAll(schemes['light-high-contrast'] as Map<String, dynamic>? ?? {});

    final darkMediumContrast = Map<String, dynamic>.from(darkBase)
      ..addAll(schemes['dark-medium-contrast'] as Map<String, dynamic>? ?? {});

    final darkHighContrast = Map<String, dynamic>.from(darkBase)
      ..addAll(schemes['dark-high-contrast'] as Map<String, dynamic>? ?? {});

    return AppTheme(
      name: json['name'] ?? 'Unnamed Theme',
      gradientColors: gradient,
      // light
      light: colorSchemeFromJson(lightBase, true),
      lightMediumContrast: colorSchemeFromJson(lightMediumContrast, true),
      lightHighContrast: colorSchemeFromJson(lightHighContrast, true),
      // dark
      dark: colorSchemeFromJson(darkBase, false),
      darkMediumContrast: colorSchemeFromJson(darkMediumContrast, false),
      darkHighContrast: colorSchemeFromJson(darkHighContrast, false),
    );
  }
}
