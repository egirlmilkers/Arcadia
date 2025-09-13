import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../theme/manager.dart';

/// A widget that displays the welcome screen when there is no active chat.
///
/// This widget shows a greeting message and a few suggestion cards to help
/// the user get started.
class WelcomeUI extends StatelessWidget {
  const WelcomeUI({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = context.watch<ThemeManager>();
    final gradientColors =
        themeManager.currentTheme?.gradientColors ??
        [theme.colorScheme.primary, theme.colorScheme.tertiary];

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The main greeting message with a gradient effect.
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                "Hello, there",
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2),
            // The secondary greeting message.
            Text(
              "How can I help you today?",
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
            const SizedBox(height: 40),
            // The row of suggestion cards.
            Row(
              children: [
                const Expanded(
                  child: SuggestionCard(icon: Icons.code, text: "Help me code"),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: SuggestionCard(icon: Icons.edit, text: "Help me write"),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: SuggestionCard(icon: Icons.lightbulb_outline, text: "Give me ideas"),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: SuggestionCard(icon: Icons.flight_takeoff, text: "Help me plan"),
                ),
              ],
            ).animate(delay: 100.ms).fadeIn(delay: 600.ms, duration: 500.ms).slideX(begin: 0.2),
          ],
        ),
      ),
    );
  }
}

/// A card that displays a suggestion for what the user can do with the app.
class SuggestionCard extends StatelessWidget {
  /// The icon to display on the card.
  final IconData icon;

  /// The text to display on the card.
  final String text;
  const SuggestionCard({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The icon for the suggestion.
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            // The text for the suggestion.
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
