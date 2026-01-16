import 'dart:io';

import 'package:flutter/widgets.dart';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    debugPrint('Directory lib not found');
    return;
  }

  dir.listSync(recursive: true).forEach((file) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      if (content.contains('.withValues')) {
        String newContent = content;

        // Find all occurrences of .withValues
        int startIndex = 0;
        while (true) {
          startIndex = newContent.indexOf('.withValues', startIndex);
          if (startIndex == -1) break;

          // Find the start of the argument list '('
          int parenStart = newContent.indexOf('(', startIndex);
          if (parenStart == -1) {
            startIndex += 11;
            continue;
          }

          // Find the balanced closing ')'
          int parenEnd = -1;
          int balance = 0;
          for (int i = parenStart; i < newContent.length; i++) {
            if (newContent[i] == '(') {
              balance++;
            } else if (newContent[i] == ')') {
              balance--;
              if (balance == 0) {
                parenEnd = i;
                break;
              }
            }
          }

          if (parenEnd != -1) {
            final fullArgs = newContent
                .substring(parenStart + 1, parenEnd)
                .trim();
            // Extract alpha value. Handle "alpha: value" or just "value"
            String alpha = fullArgs;
            if (alpha.contains('alpha:')) {
              alpha = alpha.substring(alpha.indexOf('alpha:') + 6).trim();
            }
            // Remove trailing commas
            if (alpha.endsWith(',')) {
              alpha = alpha.substring(0, alpha.length - 1).trim();
            }

            final replacement = '.withOpacity($alpha)';
            newContent = newContent.replaceRange(
              startIndex,
              parenEnd + 1,
              replacement,
            );
            // Don't skip ahead, as we modified the string, start search from new index
            startIndex += replacement.length;
          } else {
            startIndex += 11;
          }
        }

        if (newContent != content) {
          file.writeAsStringSync(newContent);
          debugPrint('Updated: ${file.path}');
        }
      }
    }
  });
}
