import 'package:flutter/material.dart';

import 'onboarding_design_tokens.dart';

/// Live passport preview — emoji micro-tiles aligned with landlord dashboard.
class PassportPreviewCard extends StatelessWidget {
  const PassportPreviewCard({
    super.key,
    required this.displayName,
    required this.location,
    required this.languages,
  });

  final String displayName;
  final String location;
  final List<String> languages;

  static const _tileFill = Color(0xFFF1F5F9);
  static const _tileBorder = Color(0xFFE2E8F0);
  static const _titleColor = Color(0xFF1E293B);
  static const _subtitleMuted = Color(0xFF64748B);
  static const _placeholder = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim();
    final loc = location.trim();
    final langs = languages.where((l) => l.trim().isNotEmpty).toList();

    return SizedBox(
      width: OnboardingTokens.passportWidth,
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: OnboardingTokens.inputBorder),
        ),
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your Public Passport',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 14),
              _PassportMicroTile(
                emoji: '👤',
                title: 'Identity',
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  child: Text(
                    name.isEmpty ? 'Your name' : name,
                    key: ValueKey(name.isEmpty ? 'name-empty' : name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: name.isEmpty ? _placeholder : _titleColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PassportMicroTile(
                emoji: '📍',
                title: 'Current Base',
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  child: Text(
                    loc.isEmpty ? 'Current area' : loc,
                    key: ValueKey(loc.isEmpty ? 'loc-empty' : loc),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: loc.isEmpty ? _placeholder : _subtitleMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PassportMicroTile(
                emoji: '🗣️',
                title: 'Languages',
                child: langs.isEmpty
                    ? Text(
                        'Add languages',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _placeholder,
                          height: 1.35,
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final language in langs)
                            _LanguageCapsule(label: language),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportMicroTile extends StatelessWidget {
  const _PassportMicroTile({
    required this.emoji,
    required this.title,
    required this.child,
  });

  final String emoji;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PassportPreviewCard._tileFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PassportPreviewCard._tileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 18, height: 1.1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PassportPreviewCard._titleColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCapsule extends StatelessWidget {
  const _LanguageCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PassportPreviewCard._tileBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
          height: 1.2,
        ),
      ),
    );
  }
}
