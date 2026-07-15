import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Fixed-width emoji prefix + clean typography (no emoji inside title strings).
class EmojiLeadingRow extends StatelessWidget {
  const EmojiLeadingRow({
    super.key,
    required this.emoji,
    required this.text,
    required this.style,
    this.emojiWidth = 24,
    this.emojiFontSize = 16,
    this.gap = 8,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.maxLines,
    this.overflow,
  });

  final String emoji;
  final String text;
  final TextStyle style;
  final double emojiWidth;
  final double emojiFontSize;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        SizedBox(
          width: emojiWidth,
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: emojiFontSize,
              height: 1.1,
              fontFamily: AppTypography.emojiFontFamily,
              fontFamilyFallback: AppTypography.emojiFontFallback,
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
      ],
    );
  }
}
