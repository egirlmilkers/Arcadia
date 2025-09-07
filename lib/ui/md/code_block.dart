import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import '../../util.dart';

class CodeBlock extends StatelessWidget {
  final String code;
  final String language;
  final Brightness brightness;

  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final Map<String, TextStyle> theme = (brightness == Brightness.dark
        ? atomOneDarkTheme
        : atomOneLightTheme);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent, // Background color of the code block
        borderRadius: BorderRadius.circular(12.0),
      ),
      // ClipRRect ensures the child's corners are also rounded
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
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
                  Text(
                    language == '' ? 'plain text' : language,
                    style: TextStyle(
                      fontFamily: 'GoogleSansCode',
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 700),
                      ],
                      color: theme['root']?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: theme['root']?.color?.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.trim()));
                      showCopiedToast(context, appTheme.colorScheme);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 1.5),

            // Code Section
            Container(
              decoration: BoxDecoration(
                color: theme['root']?.backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  child: HighlightView(
                    cleanCode(code),
                    language: language,
                    theme: theme,
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 20,
                      bottom: 6,
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'GoogleSansCode',
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 400),
                      ],
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

String cleanCode(String code) {
  final lines = code.split('\n');
  int minIndent = -1;

  // 1. Find the minimum indentation of all non-empty lines
  for (final line in lines) {
    if (line.trim().isNotEmpty) {
      final currentIndent = line.length - line.trimLeft().length;
      if (minIndent == -1 || currentIndent < minIndent) {
        minIndent = currentIndent;
      }
    }
  }

  // do nothing if no weird indents
  if (minIndent <= 0) return code.trim();

  // 2. Remove that minimum indentation from every line
  final cleanedCode = lines
      .map((line) => line.length > minIndent ? line.substring(minIndent) : '')
      .join('\n');

  // 3. Reconstruct the code block
  return cleanedCode;
}
