import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'themes.dart';

enum ContrastLevel { standard, medium, high }

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedTheme = 'Gemini';
  ContrastLevel _contrastLevel = ContrastLevel.standard;
  bool _useDynamicColor = false;
  bool dynamicColorAvailable = false;

  bool _loading = true;

  // available themes
  List<AppTheme> _themes = [];

  ThemeManager() {
    _load();
  }

  // getters
  bool get loading => _loading;
  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  List<AppTheme> get themes => _themes;
  String get selectedTheme => _selectedTheme;
  ContrastLevel get contrastLevel => _contrastLevel;

  // A convenient getter for the full current theme object
  AppTheme? get currentTheme {
    if (_themes.isEmpty) return null;
    return _themes.firstWhere(
      (t) => t.name == _selectedTheme,
      orElse: () => _themes.first,
    );
  }

  Future<void> _load() async {
    await _loadThemes();
    await _loadSettings();

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadThemes() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().where(
        (path) => path.startsWith('assets/themes/'),
      );

      final List<AppTheme> loadedThemes = [];
      for (final path in assets) {
        final string = await rootBundle.loadString(path);
        final themeJson = json.decode(string);
        loadedThemes.add(AppTheme.fromJson(themeJson));
      }
      _themes = loadedThemes;
    } catch (e) {
      debugPrint('Error loading themes:\n$e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode =
        ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
    _selectedTheme =
        prefs.getString('selectedTheme') ??
        (_themes.isNotEmpty ? _themes.first.name : 'Gemini');
    _contrastLevel = ContrastLevel
        .values[prefs.getInt('contrastLevel') ?? ContrastLevel.standard.index];
    _useDynamicColor = prefs.getBool('useDynamicColor') ?? false;
  }

  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setString('selectedTheme', _selectedTheme);
    await prefs.setInt('contrastLevel', _contrastLevel.index);
    await prefs.setBool('useDynamicColor', _useDynamicColor);
  }

  // setters
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setDynamicColor(bool value) {
    _useDynamicColor = value;
    _saveSettings();
    notifyListeners();
  }

  void setSelectedTheme(String themeName) {
    if (_themes.any((t) => t.name == themeName)) {
      _selectedTheme = themeName;
      _saveSettings();
      notifyListeners();
    }
  }

  void setContrastLevel(ContrastLevel lvl) {
    _contrastLevel = lvl;
    _saveSettings();
    notifyListeners();
  }

  // methods
  ThemeData _getThemeData(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'GoogleSans',
    );
  }

  ThemeData getTheme(Brightness brightness, {ColorScheme? scheme}) {
    dynamicColorAvailable = scheme != null;
    if (useDynamicColor && scheme != null) {
      return _getThemeData(scheme);
    }

    final selected = currentTheme;
    if (selected == null) {
      // Safe fallback if no themes are loaded
      return ThemeData(
        brightness: brightness,
        useMaterial3: true,
        fontFamily: 'GoogleSans',
      );
    }

    if (brightness == Brightness.dark) {
      switch (_contrastLevel) {
        case ContrastLevel.standard:
          return _getThemeData(selected.dark);
        case ContrastLevel.medium:
          return _getThemeData(selected.darkMediumContrast);
        case ContrastLevel.high:
          return _getThemeData(selected.darkHighContrast);
      }
    } else {
      switch (_contrastLevel) {
        case ContrastLevel.standard:
          return _getThemeData(selected.light);
        case ContrastLevel.medium:
          return _getThemeData(selected.lightMediumContrast);
        case ContrastLevel.high:
          return _getThemeData(selected.lightHighContrast);
      }
    }
  }
}
