import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'settings.dart';

class SideNav extends StatelessWidget {
  final VoidCallback onNewChat;
  final bool isExpanded;
  final VoidCallback onToggle;

  const SideNav({
    super.key,
    required this.onNewChat,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: 200.ms,
      width: isExpanded ? 280 : 80,
      color: theme.colorScheme.surfaceContainerLowest,
      child: ClipRect(
        child: OverflowBox(
          // Allow the content to render at its maximum width, independent
          // of the AnimatedContainer's current animation frame.
          minWidth: 280,
          maxWidth: 280,
          alignment: Alignment.centerLeft,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              // With OverflowBox, we must always align content to the start.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onToggle,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                // The Center widget has been removed to ensure left alignment during animation.
                isExpanded
                    ? ElevatedButton(
                        onPressed: onNewChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor:
                              theme.colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16.0),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note),
                            SizedBox(width: 8),
                            Text("New Chat"),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: onNewChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor:
                              theme.colorScheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.edit_note),
                      ),
                const SizedBox(height: 24),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text("Recent", style: theme.textTheme.titleSmall),
                  ),
                if (isExpanded)
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title:
                              const Text("Recipe for a great weekend..."),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: const Text(
                              "Flutter state management explained"),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  height: 1,
                  width: isExpanded ? 280 - 32 : 80 - 32,
                  color: theme.dividerColor,
                ),
                isExpanded
                    ? ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text("Settings"),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ));
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ));
                        },
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}