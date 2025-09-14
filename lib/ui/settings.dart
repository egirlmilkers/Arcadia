import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/logging.dart';
import '../theme/manager.dart';
import '../util.dart';

/// A data class for storing named API keys.
class ApiKey {
  String name;
  String key;

  ApiKey({required this.name, required this.key});

  Map<String, dynamic> toJson() => {'name': name, 'key': key};

  factory ApiKey.fromJson(Map<String, dynamic> json) =>
      ApiKey(name: json['name'] as String, key: json['key'] as String);
}

/// A page for displaying and managing application settings.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '...';
  String _platformInfo = '...';
  String _dynamicColorLabel = 'Dynamic Color';

  List<ApiKey> _apiKeys = [];

  @override
  void initState() {
    super.initState();
    _initAppInfo();
    _loadApiKeys();
  }

  /// Loads the list of API keys from shared preferences.
  Future<void> _loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = prefs.getString('api_keys');
    var loadedKeys = <ApiKey>[];

    if (keysJson != null && keysJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(keysJson);
        loadedKeys = decoded.map((e) => ApiKey.fromJson(e)).toList();
      } catch (e, s) {
        ArcadiaLog().error('Failed to decode API keys', e, s);
      }
    }

    // Ensure the default Gemini key always exists.
    if (!loadedKeys.any((k) => k.name == 'Gemini')) {
      loadedKeys.insert(0, ApiKey(name: 'Gemini', key: ''));
    }

    setState(() {
      _apiKeys = loadedKeys;
    });

    await _saveApiKeys();
  }

  /// Saves the full list of API keys to shared preferences.
  Future<void> _saveApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keysJson = jsonEncode(_apiKeys.map((k) => k.toJson()).toList());
    await prefs.setString('api_keys', keysJson);
  }

  /// Initializes the application information, such as version and platform details.
  Future<void> _initAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = await _getPlatformInfo();

    if (!kIsWeb && Platform.isAndroid) {
      _dynamicColorLabel = 'Material You';
    }

    if (mounted) {
      setState(() {
        _version = '${packageInfo.version} (${packageInfo.buildNumber})';
        _platformInfo = platform;
      });
    }
  }

  /// Returns a string representing the current platform and its version.
  Future<String> _getPlatformInfo() async {
    if (kIsWeb) return 'Web';

    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.productName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return 'macOS ${macInfo.osRelease}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return 'Linux (${linuxInfo.prettyName})';
      }
    } catch (e, s) {
      ArcadiaLog().error('Failed to get platform info', e, s);
      return 'Platform Unknown';
    }
    return 'Unsupported Platform';
  }

  /// Shows a dialog for selecting an option from a list.
  void _showOptionSelectDialog<T>({
    required BuildContext context,
    required String title,
    IconData? icon,
    required List<T> options,
    required T selection,
    required String Function(T) optionLabelBuilder,
    required Function(T) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Column(
            children: [
              if (icon != null) Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          content: SizedBox(
            width: double.minPositive,
            child: RadioGroup<T>(
              groupValue: selection,
              onChanged: (T? value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.of(dialogContext).pop();
                }
              },
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return RadioListTile<T>(title: Text(optionLabelBuilder(option)), value: option);
                },
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  /// Shows a dialog to add or edit an API key.
  Future<void> _showAddOrEditApiKeyDialog({ApiKey? existingApiKey}) async {
    final isEditing = existingApiKey != null;
    final nameController = TextEditingController(text: existingApiKey?.name ?? '');
    final keyController = TextEditingController(text: existingApiKey?.key ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit API Key' : 'Add API Key'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name Field
                SizedBox(
                  width: 350,
                  child: TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name'),
                    enabled: existingApiKey?.name != 'Gemini',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
                      if (!isEditing &&
                          _apiKeys.any((k) => k.name.toLowerCase() == value.trim().toLowerCase())) {
                        return 'This name already exists';
                      }
                      return null;
                    },
                  ),
                ),

                // Spacer
                const SizedBox(height: 8),

                // Key Field
                SizedBox(
                  width: 350,
                  child: TextFormField(
                    controller: keyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      hintText: 'Enter your API key',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final key = keyController.text.trim();
                  setState(() {
                    if (isEditing) {
                      existingApiKey.key = key;
                    } else {
                      _apiKeys.add(ApiKey(name: name, key: key));
                    }
                  });
                  _saveApiKeys();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Shows the main dialog for managing all API keys.
  void _showApiKeyManagementDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('API Keys'),
              content: SizedBox(
                width: 500,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _apiKeys.length,
                  itemBuilder: (context, index) {
                    final apiKey = _apiKeys[index];
                    final isDefault = apiKey.name == 'Gemini';

                    return ListTile(
                      title: Text(apiKey.name),
                      subtitle: apiKey.key.isNotEmpty && apiKey.key.length > 4
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '•' * (apiKey.key.length - 4),
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                                Text(apiKey.key.substring(apiKey.key.length - 4)),
                              ],
                            )
                          : Text('Not set'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                            onPressed: () async {
                              await _showAddOrEditApiKeyDialog(existingApiKey: apiKey);
                              setDialogState(() {}); // Rebuild list after editing
                            },
                          ),
                          if (!isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDeleteApiKey(apiKey, setDialogState),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await _showAddOrEditApiKeyDialog();
                    setDialogState(() {});
                  },
                  child: const Text('Add New'),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a confirmation dialog before deleting an API key.
  void _confirmDeleteApiKey(ApiKey apiKey, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (deleteContext) => AlertDialog(
        title: const Text('Delete Key?'),
        content: Text('Are you sure you want to delete the key named "${apiKey.name}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(deleteContext).pop(),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              setState(() {
                _apiKeys.removeWhere((k) => k.name == apiKey.name);
              });
              _saveApiKeys();
              Navigator.of(deleteContext).pop();
              setDialogState(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        final bool customStyleAllowed = !themeManager.useDynamicColor;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  const SettingsHeader('Appearance'),
                  SettingsListTile(
                    title: 'App theme',
                    subtitle: themeManager.themeMode.name.capitalize(),
                    onTap: () => _showOptionSelectDialog(
                      context: context,
                      title: 'App theme',
                      icon: Icons.palette_outlined,
                      options: ThemeMode.values,
                      selection: themeManager.themeMode,
                      optionLabelBuilder: (m) => m.name.capitalize(),
                      onSelected: (m) => themeManager.setThemeMode(m),
                    ),
                  ),
                  SettingsListTile(
                    title: 'Style',
                    subtitle: themeManager.selectedTheme,
                    onTap: () => _showOptionSelectDialog(
                      context: context,
                      title: 'Style',
                      icon: Icons.colorize_outlined,
                      options: themeManager.themes.map((t) => t.name).toList(),
                      selection: themeManager.selectedTheme,
                      optionLabelBuilder: (name) => name,
                      onSelected: (name) => themeManager.setSelectedTheme(name),
                    ),
                    enabled: customStyleAllowed,
                  ),
                  ListTile(
                    title: const Text('Contrast level'),
                    enabled: customStyleAllowed,
                    subtitle: SegmentedButton<ContrastLevel>(
                      segments: const [
                        ButtonSegment(value: ContrastLevel.standard, label: Text('Default')),
                        ButtonSegment(value: ContrastLevel.medium, label: Text('Medium')),
                        ButtonSegment(value: ContrastLevel.high, label: Text('High')),
                      ],
                      selected: {themeManager.contrastLevel},
                      onSelectionChanged: customStyleAllowed
                          ? (selection) => themeManager.setContrastLevel(selection.first)
                          : null,
                    ),
                  ),
                  SwitchListTile(
                    title: Text(_dynamicColorLabel),
                    subtitle: const Text('Use colors from your system\'s theme'),
                    value: themeManager.useDynamicColor,
                    onChanged: themeManager.dynamicColorAvailable
                        ? (value) => themeManager.setDynamicColor(value)
                        : null,
                  ),
                  const Divider(height: 24),
                  const SettingsHeader('API'),
                  SettingsListTile(
                    title: 'Manage API Keys',
                    subtitle: '${_apiKeys.length} key${_apiKeys.length > 1 ? 's' : ''} stored',
                    onTap: _showApiKeyManagementDialog,
                  ),
                  const Divider(height: 24),
                  const SettingsHeader('About'),
                  SettingsListTile(title: 'Version', subtitle: _version),
                  SettingsListTile(title: 'Platform', subtitle: _platformInfo),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A custom header widget for settings sections.
class SettingsHeader extends StatelessWidget {
  /// The title of the header.
  final String title;
  const SettingsHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// A custom list tile widget for settings items.
class SettingsListTile extends StatelessWidget {
  /// The title of the list tile.
  final String title;

  /// The subtitle of the list tile.
  final String subtitle;

  /// A callback function that is called when the tile is tapped.
  final VoidCallback? onTap;

  /// Whether the tile is enabled.
  final bool enabled;

  const SettingsListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w300)),
      onTap: onTap,
      enabled: enabled,
    );
  }
}
