import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/manager.dart';
import '../util.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '...';
  String _platformInfo = '...';
  String _dynamicColorLabel = 'Dynamic Color';
  String _apiKey = '...';

  @override
  void initState() {
    super.initState();
    _initAppInfo();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? 'Not set';
    });
  }

  Future<void> _saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', apiKey);
    setState(() {
      _apiKey = apiKey;
    });
  }

  // get the version from the package info
  Future<void> _initAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = await _getPlatformInfo();

    if (!kIsWeb && Platform.isAndroid) _dynamicColorLabel = 'Material You';

    if (mounted) {
      setState(() {
        _version = packageInfo.version;
        _platformInfo = platform;
      });
    }
  }

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
    } catch (e) {
      return 'Platform Unknown';
    }
    return 'Unsupported Platform';
  }

  // FIX: Updated dialog to use the new RadioGroup widget
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
        // Use StatefulBuilder to manage the temporary selection state within the dialog
        return StatefulBuilder(
          builder: (context, setState) {
            T? currentSelection = selection;
            return AlertDialog(
              title: Column(
                children: [
                  if (icon != null) Icon(icon, size: 24),
                  SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              content: SizedBox(
                width: double.minPositive,
                // The new RadioGroup widget handles the state for its children
                child: RadioGroup<T>(
                  groupValue: currentSelection,
                  onChanged: (T? value) {
                    // When an option is tapped, this callback is fired.
                    // We immediately apply the change and close the dialog.
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
                      // RadioListTile no longer needs groupValue or onChanged
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

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set API Key'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter your Gemini API Key'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _saveApiKey(controller.text);
                Navigator.of(context).pop();
              },
              child: Text('Save'),
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
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  // Theme section
                  SettingsHeader('Appearance'),

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
                        ButtonSegment(
                          value: ContrastLevel.standard,
                          label: Text('Default'),
                        ),
                        ButtonSegment(
                          value: ContrastLevel.medium,
                          label: Text('Medium'),
                        ),
                        ButtonSegment(
                          value: ContrastLevel.high,
                          label: Text('High'),
                        ),
                      ],
                      selected: {themeManager.contrastLevel},
                      onSelectionChanged: customStyleAllowed
                          ? (selection) =>
                                themeManager.setContrastLevel(selection.first)
                          : null,
                    ),
                  ),

                  SwitchListTile(
                    title: Text(_dynamicColorLabel),
                    subtitle: const Text(
                      'Use colors from your system\'s theme',
                    ),
                    value: themeManager.useDynamicColor,
                    onChanged: themeManager.dynamicColorAvailable
                        ? (value) => themeManager.setDynamicColor(value)
                        : null,
                  ),

                  const Divider(height: 24),

                  SettingsHeader('API'),
                  SettingsListTile(
                    title: 'Gemini API Key',
                    subtitle: _apiKey.length > 4
                        ? '••••••••${_apiKey.substring(_apiKey.length - 4)}'
                        : 'Not set',
                    onTap: _showApiKeyDialog,
                  ),

                  const Divider(height: 24),

                  SettingsHeader('About'),
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

// custom widgets
class SettingsHeader extends StatelessWidget {
  final String title;
  const SettingsHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class SettingsListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
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
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      enabled: enabled,
    );
  }
}
