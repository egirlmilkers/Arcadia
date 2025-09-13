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
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _initAppInfo();
    _loadApiKey();
  }

  /// Loads the Gemini API key from shared preferences.
  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  /// Saves the Gemini API key to shared preferences.
  Future<void> _saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', apiKey);
    setState(() {
      _apiKey = apiKey;
    });
    Logging().info('Saved new API key.');
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
      Logging().error('Failed to get platform info', e, s);
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
        return StatefulBuilder(
          builder: (context, setState) {
            T? currentSelection = selection;
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
                  groupValue: currentSelection,
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
                      return RadioListTile<T>(
                        title: Text(optionLabelBuilder(option)),
                        value: option,
                      );
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
      },
    );
  }

  /// Shows a dialog for setting the Gemini API key.
  void _showApiKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set API Key'),
          content: SizedBox(
            width: 300,
            child: TextField(
              controller: controller,
              obscureText: true,
              maxLines: 1,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Enter your Gemini API Key'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                _saveApiKey(controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        final bool customStyleAllowed = !themeManager.useDynamicColor;

        return Scaffold(
          // The app bar for the settings page.
          appBar: AppBar(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          // The main body of the settings page.
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  // The "Appearance" section.
                  const SettingsHeader('Appearance'),

                  // The setting for the app theme.
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

                  // The setting for the color style.
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

                  // The setting for the contrast level.
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

                  // The setting for dynamic color.
                  SwitchListTile(
                    title: Text(_dynamicColorLabel),
                    subtitle: const Text('Use colors from your system\'s theme'),
                    value: themeManager.useDynamicColor,
                    onChanged: themeManager.dynamicColorAvailable
                        ? (value) => themeManager.setDynamicColor(value)
                        : null,
                  ),

                  const Divider(height: 24),

                  // The "API" section.
                  const SettingsHeader('API'),
                  // The setting for the Gemini API key.
                  SettingsListTile(
                    title: 'Gemini API Key',
                    subtitle: _apiKey != null && _apiKey!.length > 4
                        ? '••••••••${_apiKey!.substring(_apiKey!.length - 4)}'
                        : 'Not set',
                    onTap: _showApiKeyDialog,
                  ),

                  const Divider(height: 24),

                  // The "About" section.
                  const SettingsHeader('About'),
                  // The version and platform information.
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
