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
      width: isExpanded ? 280 : 74,
      color: theme.colorScheme.surfaceContainerLowest,
      child: ClipRect(
        child: OverflowBox(
          // Allow the content to render at its maximum width, independent
          // of the AnimatedContainer's current animation frame.
          minWidth: 280,
          maxWidth: 280,
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              // With OverflowBox, we must always align content to the start.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onToggle,
                ),
                const SizedBox(height: 10),
                CustomNavButton(
                  isExpanded: isExpanded,
                  onPressed: onNewChat,
                  icon: Icons.rate_review_outlined,
                  label: "New Chat",
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
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
                          title: const Text("Recipe for a great weekend..."),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: const Text(
                            "Flutter state management explained",
                          ),
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
                CustomNavButton(
                  isExpanded: isExpanded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  icon: Icons.settings,
                  label: "Settings",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomNavButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CustomNavButton({
    required this.isExpanded,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(isExpanded ? double.infinity : 48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          if (isExpanded) ...[const SizedBox(width: 8), Text(label)],
        ],
      ),
    );
  }
}
