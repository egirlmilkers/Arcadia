import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A widget that displays a spinning gradient circle and a "Thinking..." message.
///
/// This widget is used to indicate that the application is processing a request.
class ThinkingSpinner extends StatefulWidget {
  /// The text to display next to the spinner.
  final String text;

  const ThinkingSpinner({super.key, this.text = "Thinking..."});

  @override
  State<ThinkingSpinner> createState() => _ThinkingSpinnerState();
}

class _ThinkingSpinnerState extends State<ThinkingSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = theme.extension<ThemeGradient>()?.gradientColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // The rotating gradient circle.
        RotationTransition(
          turns: _controller,
          child: CustomPaint(
            painter: GradientCirclePainter(
              gradientColors: gradient ?? [scheme.primary, scheme.secondary, scheme.tertiary],
            ),
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
        const SizedBox(width: 8),
        // The "Thinking..." text.
        Text(widget.text, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// A custom painter that draws a circle with a gradient border.
class GradientCirclePainter extends CustomPainter {
  /// The list of colors to use for the gradient.
  final List<Color> gradientColors;

  GradientCirclePainter({required this.gradientColors});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = SweepGradient(colors: gradientColors, startAngle: 0.0, endAngle: math.pi * 2);

    paint.shader = gradient.createShader(rect);

    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

/// A theme extension for providing a list of gradient colors.
class ThemeGradient extends ThemeExtension<ThemeGradient> {
  /// The list of colors for the gradient.
  final List<Color> gradientColors;

  ThemeGradient({required this.gradientColors});

  @override
  ThemeExtension<ThemeGradient> copyWith({List<Color>? gradientColors}) {
    return ThemeGradient(gradientColors: gradientColors ?? this.gradientColors);
  }

  @override
  ThemeExtension<ThemeGradient> lerp(ThemeExtension<ThemeGradient>? other, double t) {
    if (other is! ThemeGradient) {
      return this;
    }
    return ThemeGradient(gradientColors: gradientColors);
  }
}
