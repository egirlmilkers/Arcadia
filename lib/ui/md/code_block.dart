import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../syntax/syntax_view.dart';
import '../../syntax/themes.dart';
import '../../util.dart';

/// A widget for displaying a block of code with syntax highlighting.
class CodeBlock extends StatefulWidget {
  /// The code to display.
  final String code;

  /// The programming language of the code.
  final String language;

  /// The brightness of the theme to use for syntax highlighting.
  final Brightness brightness;

  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.brightness,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    // Determine the syntax highlighting theme based on the app's brightness.
    final Map<String, TextStyle> theme =
        (widget.brightness == Brightness.dark
            ? themes['atom-one-dark']
            : themes['atom-one-light']) ??
        const {};

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header of the code block, which displays the language and a copy button.
            Container(
              decoration: BoxDecoration(
                color: theme['root']?.backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // The name of the programming language.
                  Text(
                    widget.language == '' ? 'plaintext' : widget.language,
                    style: TextStyle(
                      fontFamily: 'GoogleSansCode',
                      fontVariations: const [FontVariation('wght', 700.0)],
                      color: theme['root']?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  // The button for copying the code to the clipboard.
                  IconButton(
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: theme['root']?.color?.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.code.trim()),
                      );
                      showCopiedToast(context, appTheme.colorScheme);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1.5),

            // The main content of the code block.
            Container(
              decoration: BoxDecoration(
                color: theme['root']?.backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                // A scrollbar for horizontally long code.
                child: Scrollbar(
                  thumbVisibility: true,
                  trackVisibility: true,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    // The SyntaxView widget, which handles the actual syntax highlighting.
                    child: SyntaxView(
                      cleanCode(widget.code),
                      language: widget.language,
                      theme: theme,
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 20,
                        bottom: 16,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'GoogleSansCode',
                        fontVariations: [FontVariation('wght', 400.0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Removes common leading indentation from a block of code.
String cleanCode(String code) {
  final lines = code.split('\n');
  int minIndent = -1;

  for (final line in lines) {
    if (line.trim().isNotEmpty) {
      final currentIndent = line.length - line.trimLeft().length;
      if (minIndent == -1 || currentIndent < minIndent) {
        minIndent = currentIndent;
      }
    }
  }

  if (minIndent <= 0) return code.trim();

  final cleanedCode = lines
      .map((line) => line.length > minIndent ? line.substring(minIndent) : '')
      .join('\n');

  return cleanedCode;
}
