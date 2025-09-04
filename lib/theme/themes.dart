import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final ColorScheme light;
  final ColorScheme lightMediumContrast;
  final ColorScheme lightHighContrast;
  final ColorScheme dark;
  final ColorScheme darkMediumContrast;
  final ColorScheme darkHighContrast;

  AppTheme({
    required this.name,
    required this.light,
    required this.lightMediumContrast,
    required this.lightHighContrast,
    required this.dark,
    required this.darkMediumContrast,
    required this.darkHighContrast,
  });

  // create app theme from the json
  factory AppTheme.fromJson(Map<String, dynamic> json) {
    // util for getting a specific scheme
    ColorScheme colorSchemeFromJson(
      Map<String, dynamic> schemeJson,
      bool light,
    ) {
      // util for turning the hex to something flutter can use
      Color colorFromHex(String hex) =>
          Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);

      return ColorScheme(
        brightness: light ? Brightness.light : Brightness.dark,
        primary: colorFromHex(schemeJson['primary']),
        surfaceTint: colorFromHex(schemeJson['surfaceTint']),
        onPrimary: colorFromHex(schemeJson['onPrimary']),
        primaryContainer: colorFromHex(schemeJson['primaryContainer']),
        onPrimaryContainer: colorFromHex(schemeJson['onPrimaryContainer']),
        secondary: colorFromHex(schemeJson['secondary']),
        onSecondary: colorFromHex(schemeJson['onSecondary']),
        secondaryContainer: colorFromHex(schemeJson['secondaryContainer']),
        onSecondaryContainer: colorFromHex(schemeJson['onSecondaryContainer']),
        tertiary: colorFromHex(schemeJson['tertiary']),
        onTertiary: colorFromHex(schemeJson['onTertiary']),
        tertiaryContainer: colorFromHex(schemeJson['tertiaryContainer']),
        onTertiaryContainer: colorFromHex(schemeJson['onTertiaryContainer']),
        error: colorFromHex(schemeJson['error']),
        onError: colorFromHex(schemeJson['onError']),
        errorContainer: colorFromHex(schemeJson['errorContainer']),
        onErrorContainer: colorFromHex(schemeJson['onErrorContainer']),
        surface: colorFromHex(schemeJson['surface']),
        onSurface: colorFromHex(schemeJson['onSurface']),
        onSurfaceVariant: colorFromHex(schemeJson['onSurfaceVariant']),
        outline: colorFromHex(schemeJson['outline']),
        outlineVariant: colorFromHex(schemeJson['outlineVariant']),
        shadow: colorFromHex(schemeJson['shadow']),
        scrim: colorFromHex(schemeJson['scrim']),
        inverseSurface: colorFromHex(schemeJson['inverseSurface']),
        inversePrimary: colorFromHex(schemeJson['inversePrimary']),
        primaryFixed: colorFromHex(schemeJson['primaryFixed']),
        onPrimaryFixed: colorFromHex(schemeJson['onPrimaryFixed']),
        primaryFixedDim: colorFromHex(schemeJson['primaryFixedDim']),
        onPrimaryFixedVariant: colorFromHex(
          schemeJson['onPrimaryFixedVariant'],
        ),
        secondaryFixed: colorFromHex(schemeJson['secondaryFixed']),
        onSecondaryFixed: colorFromHex(schemeJson['onSecondaryFixed']),
        secondaryFixedDim: colorFromHex(schemeJson['secondaryFixedDim']),
        onSecondaryFixedVariant: colorFromHex(
          schemeJson['onSecondaryFixedVariant'],
        ),
        tertiaryFixed: colorFromHex(schemeJson['tertiaryFixed']),
        onTertiaryFixed: colorFromHex(schemeJson['onTertiaryFixed']),
        tertiaryFixedDim: colorFromHex(schemeJson['tertiaryFixedDim']),
        onTertiaryFixedVariant: colorFromHex(
          schemeJson['onTertiaryFixedVariant'],
        ),
        surfaceDim: colorFromHex(schemeJson['surfaceDim']),
        surfaceBright: colorFromHex(schemeJson['surfaceBright']),
        surfaceContainerLowest: colorFromHex(
          schemeJson['surfaceContainerLowest'],
        ),
        surfaceContainerLow: colorFromHex(schemeJson['surfaceContainerLow']),
        surfaceContainer: colorFromHex(schemeJson['surfaceContainer']),
        surfaceContainerHigh: colorFromHex(schemeJson['surfaceContainerHigh']),
        surfaceContainerHighest: colorFromHex(
          schemeJson['surfaceContainerHighest'],
        ),
      );
    }

    final schemes = json['schemes'] as Map<String, dynamic>;
    return AppTheme(
      name: json['name'] ?? 'Unnamed Theme',
      // light
      light: colorSchemeFromJson(schemes['light'], true),
      lightMediumContrast: colorSchemeFromJson(
        schemes['light-medium-contrast'],
        true,
      ),
      lightHighContrast: colorSchemeFromJson(
        schemes['light-high-contrast'],
        true,
      ),
      // dark
      dark: colorSchemeFromJson(schemes['dark'], false),
      darkMediumContrast: colorSchemeFromJson(
        schemes['dark-medium-contrast'],
        false,
      ),
      darkHighContrast: colorSchemeFromJson(
        schemes['dark-high-contrast'],
        false,
      ),
    );
  }
}
