import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'emoji_leading_row.dart';
import 'listing_creation/listing_creation_primitives.dart';

/// Conversational page header for gamified multi-step forms.
class GamifiedFormPageHeader extends StatelessWidget {
  const GamifiedFormPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleEmoji,
  });

  final String title;
  final String subtitle;
  final String? titleEmoji;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titleEmoji != null)
          EmojiLeadingRow(
            emoji: titleEmoji!,
            text: title,
            style: listingPageTitleStyle,
            emojiFontSize: 22,
            emojiWidth: 28,
            gap: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
          )
        else
          Text(
            title,
            style: listingPageTitleStyle,
          ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: listingPageSubtitleStyle,
        ),
      ],
    );
  }
}

/// Step progress with optional navigation to completed steps.
class GamifiedFormProgress extends StatelessWidget {
  const GamifiedFormProgress({
    super.key,
    required this.current,
    this.total = 3,
    this.stepLabels = const ['Property', 'Location', 'Listing'],
    this.onStepTap,
  });

  final int current;
  final int total;
  final List<String> stepLabels;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          final label = stepLabels[current.clamp(0, stepLabels.length - 1)];
          return Row(
            children: [
              _StepLink(
                index: current,
                label: label,
                state: _StepVisual.active,
                onTap: null,
              ),
              const Spacer(),
              Text(
                '${current + 1} of $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const Spacer(),
              _StepLink(
                index: i,
                label: stepLabels[i.clamp(0, stepLabels.length - 1)],
                state: i < current
                    ? _StepVisual.complete
                    : i == current
                        ? _StepVisual.active
                        : _StepVisual.upcoming,
                onTap: i < current ? () => onStepTap?.call(i) : null,
              ),
            ],
          ],
        );
      },
    );
  }
}

enum _StepVisual { upcoming, active, complete }

class _StepLink extends StatelessWidget {
  const _StepLink({
    required this.index,
    required this.label,
    required this.state,
    this.onTap,
  });

  final int index;
  final String label;
  final _StepVisual state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == _StepVisual.active;
    final complete = state == _StepVisual.complete;
    final prefix = complete ? '✓' : '${index + 1}';

    final textColor = active
        ? const Color(0xFF111827)
        : complete
            ? const Color(0xFF4B5563)
            : const Color(0xFF9CA3AF);
    final weight = active ? FontWeight.w600 : FontWeight.w500;

    final child = Text(
      '$prefix $label',
      style: TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: textColor,
        decoration: onTap != null ? TextDecoration.underline : TextDecoration.none,
        decorationColor: const Color(0xFF9CA3AF),
      ),
    );

    if (onTap == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: child,
        ),
      ),
    );
  }
}

/// Bottom navigation bar for wizard pages.
class GamifiedFormNavBar extends StatelessWidget {
  const GamifiedFormNavBar({
    super.key,
    this.onBack,
    this.onNext,
    this.onSubmit,
    this.onSkipToBonus,
    this.nextLabel = 'Continue →',
    this.submitLabel = 'Publish Listing 🚀',
    this.backLabel = '← Back',
    this.skipLabel = 'Add bonus details',
    this.showBack = true,
    this.showNext = false,
    this.showSubmit = false,
    this.showSkipToBonus = false,
    this.isSubmitting = false,
    this.enabled = true,
    this.floating = false,
    this.compact = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;
  final VoidCallback? onSkipToBonus;
  final String nextLabel;
  final String submitLabel;
  final String backLabel;
  final String skipLabel;
  final bool showBack;
  final bool showNext;
  final bool showSubmit;
  final bool showSkipToBonus;
  final bool isSubmitting;
  final bool enabled;
  final bool floating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSkipToBonus && onSkipToBonus != null) ...[
          TextButton(
            onPressed: enabled ? onSkipToBonus : null,
            child: Text(
              skipLabel,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            if (showBack)
              OutlinedButton(
                onPressed: enabled && !isSubmitting ? onBack : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 20,
                    vertical: compact ? 10 : 14,
                  ),
                  minimumSize: Size(0, compact ? 40 : 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(backLabel),
              ),
            if (showBack || showNext || showSubmit) const Spacer(),
            if (showNext)
              _PrimaryActionButton(
                label: nextLabel,
                onPressed: enabled && !isSubmitting ? onNext : null,
                floating: floating,
                compact: compact,
              ),
            if (showSubmit)
              _PrimaryActionButton(
                label: submitLabel,
                onPressed: enabled && !isSubmitting ? onSubmit : null,
                floating: floating,
                isSubmitting: isSubmitting,
                compact: compact,
              ),
          ],
        ),
      ],
    );

    if (!floating) return content;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 20),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
    required this.floating,
    this.isSubmitting = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool floating;
  final bool isSubmitting;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 22 : 28,
          vertical: compact ? 10 : 14,
        ),
        minimumSize: Size(floating ? 220 : 0, compact ? 40 : 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isSubmitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: compact ? 14 : 15,
                letterSpacing: -0.2,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
    );

    return button;
  }
}
