import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

class Model {
  final String displayName;
  final String subtitle;
  final String modelName;

  Model({
    required this.displayName,
    required this.subtitle,
    required this.modelName,
  });

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      displayName: json['displayName'],
      subtitle: json['subtitle'],
      modelName: json['modelName'],
    );
  }
}

class ModelManager extends ChangeNotifier {
  List<Model> _models = [];
  String _selectedModelName = '';
  bool _loading = true;

  ModelManager() {
    _load();
  }

  bool get loading => _loading;
  List<Model> get models => _models;
  Model get selectedModel => _models.firstWhere(
    (m) => m.modelName == _selectedModelName,
    orElse: () => _models.first,
  );

  Future<void> _load() async {
    await _loadModels();
    await _loadSettings();
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadModels() async {
    try {
      final String string = await rootBundle.loadString('assets/models.json');
      final List<dynamic> jsonList = json.decode(string);
      _models = jsonList.map((json) => Model.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading models: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedModelName =
        prefs.getString('selectedModelName') ??
        (_models.isNotEmpty ? _models.first.modelName : '');
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedModelName', _selectedModelName);
  }

  void setSelectedModel(String modelName) {
    if (_models.any((m) => m.modelName == modelName)) {
      _selectedModelName = modelName;
      _saveSettings();
      notifyListeners();
    }
  }
}
