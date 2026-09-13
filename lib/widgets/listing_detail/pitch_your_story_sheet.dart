import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppButtonStyles;
import '../../theme/app_typography.dart';
import '../../models/marketplace_space.dart';
import '../../utils/application_pitch_text.dart';
import '../../utils/profile_data.dart';
import '../../utils/rental_date_format.dart';
import '../listing_detail_tokens.dart';

/// Lightweight pitch modal — application is created on submit.
class PitchYourStorySheet extends StatefulWidget {
  const PitchYourStorySheet({
    super.key,
    required this.hostName,
    required this.space,
    required this.session,
    required this.onSubmit,
  });

  final String hostName;
  final MarketplaceSpace space;
  final Map<String, dynamic> session;
  final Future<void> Function(String personalNote) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required String hostName,
    required MarketplaceSpace space,
    required Map<String, dynamic> session,
    required Future<void> Function(String personalNote) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PitchYourStorySheet(
        hostName: hostName,
        space: space,
        session: session,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<PitchYourStorySheet> createState() => _PitchYourStorySheetState();
}

class _PitchYourStorySheetState extends State<PitchYourStorySheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _controller.text.trim();
    if (note.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(note);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<_ProfileFact> get _profileFacts {
    final session = widget.session;
    if (widget.space == MarketplaceSpace.sharedSpace) {
      return [
        _ProfileFact(
          emoji: '✨',
          label: 'Lifestyle',
          value: _lifestyleLabel(session),
        ),
        _ProfileFact(
          emoji: '🚭',
          label: 'Smoking',
          value: _smokingLabel(session),
        ),
        _ProfileFact(
          emoji: '🗣️',
          label: 'Languages',
          value: _languagesLabel(session),
        ),
      ];
    }

    return [
      _ProfileFact(
        emoji: '📅',
        label: 'Move-in Timeline',
        value: _moveInLabel(session),
      ),
      _ProfileFact(
        emoji: '👤',
        label: 'Household Size',
        value: _householdLabel(session),
      ),
      _ProfileFact(
        emoji: '💼',
        label: 'Employment Status',
        value: _employmentLabel(session),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell the host a little about yourself',
            style: AppTypography.sectionTitle().copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Pitch Your Story to ${widget.hostName}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (final fact in _profileFacts)
            if (fact.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fact.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ListingDetailTokens.charcoal,
                            ),
                          ),
                          Text(
                            fact.value,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 6,
            maxLength: ApplicationPitchText.maxPersonalNoteLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Personal Note',
              hintText:
                  'Why are you moving?\nWhen would you like to move in?\nAnything important the host should know?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: AppButtonStyles.primaryFilled,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send application'),
            ),
          ),
        ],
      ),
    );
  }

  static String _moveInLabel(Map<String, dynamic> session) {
    final raw = ProfileData.text(session['move_in_window']).isNotEmpty
        ? ProfileData.text(session['move_in_window'])
        : ProfileData.text(session['earliest_move_in_date']);
    if (raw.isEmpty) return '';
    return RentalDateFormat.formatMoveInWindowDisplay(raw);
  }

  static String _householdLabel(Map<String, dynamic> session) {
    final occupants = session['household_occupants'];
    if (occupants is num && occupants > 0) {
      return occupants == 1 ? '1 person' : '${occupants.toInt()} people';
    }
    final type = ProfileData.text(session['occupant_type']);
    if (type.isNotEmpty) return type;
    return '';
  }

  static String _employmentLabel(Map<String, dynamic> session) {
    if (session['employment_verified'] == true) {
      return 'Employment verified';
    }
    final status = ProfileData.text(session['employment_status']);
    if (status.isNotEmpty) return status;
    return ProfileData.text(session['verification_track']);
  }

  static String _lifestyleLabel(Map<String, dynamic> session) {
    final schedule = ProfileData.text(session['schedule_type']);
    if (schedule.isNotEmpty) return schedule;
    return ProfileData.text(session['preferred_arrangement']);
  }

  static String _smokingLabel(Map<String, dynamic> session) {
    if (session['smoking_ok'] == true) return 'Smoking-friendly';
    if (session['smoking_ok'] == false) return 'Non-smoker';
    return '';
  }

  static String _languagesLabel(Map<String, dynamic> session) {
    final langs = ProfileData.languageList(session['spoken_languages']);
    if (langs.isEmpty) return '';
    return langs.take(4).join(', ');
  }
}

class _ProfileFact {
  const _ProfileFact({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final String value;
}
