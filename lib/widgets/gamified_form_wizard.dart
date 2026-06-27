import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Conversational page header for gamified multi-step forms.
class GamifiedFormPageHeader extends StatelessWidget {
  const GamifiedFormPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1E21),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Step progress: "1/3", "2/3", or "Bonus" for the optional third page.
class GamifiedFormProgress extends StatelessWidget {
  const GamifiedFormProgress({
    super.key,
    required this.current,
    this.total = 3,
    this.bonusLabel = 'Bonus',
  });

  final int current;
  final int total;
  final String bonusLabel;

  @override
  Widget build(BuildContext context) {
    final isBonus = current >= total - 1;
    final label = isBonus ? bonusLabel : '${current + 1}/$total';

    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current
                    ? AppColors.accent
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isBonus ? AppColors.accentDark : const Color(0xFF6B7280),
          ),
        ),
      ],
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
    this.nextLabel = 'Next',
    this.submitLabel = 'Save',
    this.skipLabel = 'Add bonus details',
    this.showBack = true,
    this.showNext = false,
    this.showSubmit = false,
    this.showSkipToBonus = false,
    this.isSubmitting = false,
    this.enabled = true,
    this.floating = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;
  final VoidCallback? onSkipToBonus;
  final String nextLabel;
  final String submitLabel;
  final String skipLabel;
  final bool showBack;
  final bool showNext;
  final bool showSubmit;
  final bool showSkipToBonus;
  final bool isSubmitting;
  final bool enabled;
  final bool floating;

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            if (showBack && (showNext || showSubmit)) const SizedBox(width: 12),
            if (showNext)
              _PrimaryActionButton(
                label: nextLabel,
                onPressed: enabled && !isSubmitting ? onNext : null,
                floating: floating,
              ),
            if (showSubmit)
              _PrimaryActionButton(
                label: submitLabel,
                onPressed: enabled && !isSubmitting ? onSubmit : null,
                floating: floating,
                isSubmitting: isSubmitting,
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
            constraints: const BoxConstraints(maxWidth: 720),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool floating;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        minimumSize: Size(floating ? 220 : 0, 48),
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
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
    );

    if (!floating) {
      return Expanded(child: button);
    }

    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: button,
      ),
    );
  }
}
