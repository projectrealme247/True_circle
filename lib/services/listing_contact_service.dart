import 'package:flutter/foundation.dart';

import '../utils/listing_data.dart';
import '../utils/profile_data.dart';

/// Platform-mediated contact — apply notifications and milestone handoff (MVP).
abstract final class ListingContactService {
  static String hostEmailForListing(Map<String, dynamic> listing) {
    for (final key in [
      'owner_email',
      'host_email',
      'landlord_email',
      'contact_email',
    ]) {
      final email = ProfileData.text(listing[key]);
      if (email.isNotEmpty) return email;
    }
    return '';
  }

  static Map<String, dynamic> applicantSummary({
    required Map<String, dynamic> session,
    required Map<String, dynamic> listing,
    required int compatibilityScore,
  }) {
    final budget = ProfileData.text(session['budget_max']);
    final moveIn = ProfileData.text(session['earliest_move_in_date']);
    final trustRaw = ProfileData.text(session['trust_tier']);
    final trust = trustRaw.isEmpty ? 'Just Landed' : trustRaw;
    final nameRaw = ProfileData.text(session['full_name']);
    return {
      'applicant_name': nameRaw.isEmpty ? 'Applicant' : nameRaw,
      'applicant_email': ProfileData.text(session['email']),
      'compatibility_score': compatibilityScore,
      'budget_label': budget.isEmpty ? null : '€$budget',
      'move_in_window': moveIn.isEmpty ? null : moveIn,
      'trust_tier': trust,
      'listing_title': ListingData.title(listing),
      'listing_id': ListingData.id(listing),
    };
  }

  /// Queues a host notification for a new application or viewing request.
  /// MVP: logs in debug; production would use transactional email.
  static Future<void> notifyHost({
    required Map<String, dynamic> listing,
    required Map<String, dynamic> applicantSession,
    required int compatibilityScore,
    ListingContactEvent kind = ListingContactEvent.application,
    String? viewingNote,
    String? viewingSlot,
  }) async {
    final summary = applicantSummary(
      session: applicantSession,
      listing: listing,
      compatibilityScore: compatibilityScore,
    );
    final hostEmail = hostEmailForListing(listing);
    final subject = switch (kind) {
      ListingContactEvent.application =>
        'New applicant: ${summary['listing_title']}',
      ListingContactEvent.viewingRequest =>
        'Viewing request: ${summary['listing_title']}',
    };

    final bodyLines = <String>[
      'New ${kind.label} on TrueCircle',
      '',
      'Listing: ${summary['listing_title']}',
      'Applicant: ${summary['applicant_name']}',
      'Match: $compatibilityScore%',
      if (summary['budget_label'] != null) 'Budget: ${summary['budget_label']}',
      if (summary['move_in_window'] != null)
        'Move-in: ${summary['move_in_window']}',
      'Trust: ${summary['trust_tier']}',
      if (viewingSlot != null && viewingSlot.isNotEmpty)
        'Requested slot: $viewingSlot',
      if (viewingNote != null && viewingNote.isNotEmpty) 'Note: $viewingNote',
      '',
      'Review applicants in your dashboard.',
    ];

    if (kDebugMode) {
      debugPrint(
        '[ListingContact] to=${hostEmail.isEmpty ? '(host email unknown)' : hostEmail} '
        'subject=$subject\n${bodyLines.join('\n')}',
      );
    }
  }

  /// WhatsApp deep link after shortlist milestone (host opted in).
  static String? whatsAppHandoffUri({
    required String phoneE164,
    required String listingTitle,
    required String applicantName,
  }) {
    final digits = phoneE164.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    final message = Uri.encodeComponent(
      'Hi — $applicantName re: $listingTitle on TrueCircle. '
      'Are you free for a viewing?',
    );
    return 'https://wa.me/$digits?text=$message';
  }
}

enum ListingContactEvent {
  application('application'),
  viewingRequest('viewing request');

  const ListingContactEvent(this.label);
  final String label;
}
