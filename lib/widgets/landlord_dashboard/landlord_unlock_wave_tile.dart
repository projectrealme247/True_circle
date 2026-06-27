import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors;
import '../../theme/app_typography.dart';

class LandlordUnlockWaveTile extends StatelessWidget {
  const LandlordUnlockWaveTile({
    super.key,
    required this.remainingCount,
    required this.onUnlock,
    this.isLoading = false,
  });

  final int remainingCount;
  final VoidCallback onUnlock;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final nextBatch = remainingCount.clamp(1, 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onUnlock,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.08),
                  AppColors.accentLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : const Icon(
                            Icons.waves_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revealing Top 10 Alpha Matches',
                          style: AppTypography.cardTitle().copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to summon the next wave — $nextBatch more '
                          'high-signal candidates waiting behind the curtain.',
                          style: AppTypography.detail().copyWith(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
