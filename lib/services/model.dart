import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Represents a Gemini model with its display name, subtitle, and model name.
class Model {
  /// The name of the model to be displayed in the UI.
  final String displayName;

  /// A short description of the model.
  final String subtitle;

  /// The name of the model to be used in API calls.
  final String name;

  /// The URL of the model for API calls.
  final String url;

  /// Whether the model is capable of thinking.
  final bool thinking;

  Model({
    required this.displayName,
    required this.subtitle,
    required this.name,
    required this.url,
    this.thinking = false,
  });

  /// Creates a [Model] from a JSON object.
  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      displayName: json['displayName'],
      subtitle: json['subtitle'],
      name: json['name'],
      url: json['url'],
      thinking: json['thinking'] ?? false,
    );
  }
}

/// A class that manages the available models and the currently selected model.
class ModelManager extends ChangeNotifier {
  List<Model> _models = [];
  Model? _selectedModel;
  bool _loading = true;

  ModelManager() {
    _load();
  }

  /// Whether the models are currently being loaded.
  bool get loading => _loading;

  /// The list of available models.
  List<Model> get models => _models;

  /// The currently selected model.
  Model get selectedModel =>
      _selectedModel ??
      (_models.isNotEmpty
          ? _models.first
          : Model(
              displayName: '',
              subtitle: '',
              name: '',
              url: '',
              thinking: false,
            ));

  /// Loads the models and settings from their respective sources.
  Future<void> _load() async {
    await _loadModels();
    await _loadSettings();
    _loading = false;
    notifyListeners();
  }

  /// Loads the list of available models from the `assets/models.json` file.
  Future<void> _loadModels() async {
    try {
      final String string = await rootBundle.loadString('assets/models.json');
      final List<dynamic> jsonList = json.decode(string);
      _models = jsonList.map((json) => Model.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading models: $e');
    }
  }

  /// Loads the selected model from shared preferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedModelName = prefs.getString('selectedModelName');
    if (selectedModelName != null) {
      try {
        _selectedModel = _models.firstWhere((m) => m.name == selectedModelName);
      } catch (e) {
        _selectedModel = _models.isNotEmpty ? _models.first : null;
      }
    } else {
      _selectedModel = _models.isNotEmpty ? _models.first : null;
    }
  }

  /// Saves the selected model to shared preferences.
  Future<void> _saveSettings() async {
    if (_selectedModel != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedModelName', _selectedModel!.name);
    }
  }

  /// Sets the selected model.
  void setSelectedModel(Model model) {
    if (_models.contains(model)) {
      _selectedModel = model;
      _saveSettings();
      notifyListeners();
    }
  }
}
