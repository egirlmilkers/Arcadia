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
  final String modelName;

  Model({
    required this.displayName,
    required this.subtitle,
    required this.modelName,
  });

  /// Creates a [Model] from a JSON object.
  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      displayName: json['displayName'],
      subtitle: json['subtitle'],
      modelName: json['modelName'],
    );
  }
}

/// A class that manages the available models and the currently selected model.
class ModelManager extends ChangeNotifier {
  List<Model> _models = [];
  String _selectedModelName = '';
  bool _loading = true;

  ModelManager() {
    _load();
  }

  /// Whether the models are currently being loaded.
  bool get loading => _loading;

  /// The list of available models.
  List<Model> get models => _models;

  /// The currently selected model.
  Model get selectedModel => _models.firstWhere(
    (m) => m.modelName == _selectedModelName,
    orElse: () => _models.first,
  );

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
    _selectedModelName =
        prefs.getString('selectedModelName') ??
        (_models.isNotEmpty ? _models.first.modelName : '');
  }

  /// Saves the selected model to shared preferences.
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedModelName', _selectedModelName);
  }

  /// Sets the selected model.
  void setSelectedModel(String modelName) {
    if (_models.any((m) => m.modelName == modelName)) {
      _selectedModelName = modelName;
      _saveSettings();
      notifyListeners();
    }
  }
}
