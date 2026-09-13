import 'package:flutter/material.dart';

import '../models/seeker_onboarding_enums.dart';

/// Verification paths exposed in the Grand-tier gateway.
enum VerificationGatewayPath {
  universityEmailOtp,
  offerLetterUpload,
  linkedInCorporate,
  employmentContractUpload,
  openBanking,
  inboundRelocation,
}

/// Persona-driven copy + routing for the recommended verification path.
class VerificationGatewayLabel {
  const VerificationGatewayLabel({
    required this.personaDisplayName,
    required this.path,
    required this.pathTitle,
    required this.suffixTag,
    required this.description,
    required this.route,
    required this.icon,
    this.leadingEmoji = '',
  });

  final String personaDisplayName;
  final VerificationGatewayPath path;
  final String pathTitle;
  final String suffixTag;
  final String description;
  final String route;
  final IconData icon;
  final String leadingEmoji;
}

/// Static catalog for gateway path cards.
class VerificationGatewayPathDefinition {
  const VerificationGatewayPathDefinition({
    required this.pathTitle,
    required this.description,
    required this.route,
    required this.icon,
    this.leadingEmoji = '',
  });

  final String pathTitle;
  final String description;
  final String route;
  final IconData icon;
  final String leadingEmoji;
}

/// Persona-filtered gateway layout (recommended + strict alternates).
class VerificationGatewayLayout {
  const VerificationGatewayLayout({
    required this.subtitle,
    required this.recommended,
    required this.alternates,
  });

  final String subtitle;
  final VerificationGatewayPath recommended;
  final List<VerificationGatewayPath> alternates;

  VerificationGatewayLayout copyWithSubtitle(String subtitle) =>
      VerificationGatewayLayout(
        subtitle: subtitle,
        recommended: recommended,
        alternates: alternates,
      );
}

const inboundRelocationVerificationLabel = VerificationGatewayLabel(
  personaDisplayName: 'Inbound Relocation',
  path: VerificationGatewayPath.inboundRelocation,
  pathTitle: 'Inbound Relocation Verification',
  suffixTag: '',
  description:
      'Securely upload your employment contract or letter of offer, or connect '
      'LinkedIn, to verify before you land.',
  route: '/verify/social',
  icon: Icons.upload_file_outlined,
  leadingEmoji: '💼',
);

/// Phase 1 UX hides Open Banking. Enum + catalog stay for later reactivation.
const Set<VerificationGatewayPath> phase1DormantVerificationPaths = {
  VerificationGatewayPath.openBanking,
};

const _professionalFamilyLayout = VerificationGatewayLayout(
  subtitle:
      'Complete LinkedIn or employment verification to become a Verified User.',
  recommended: VerificationGatewayPath.linkedInCorporate,
  alternates: [
    VerificationGatewayPath.employmentContractUpload,
  ],
);

bool isInboundRelocationPersona(Map<String, dynamic>? session) {
  final persona = SeekerPersona.fromSession(session);
  if (persona == SeekerPersona.relocating || persona == SeekerPersona.family) {
    return true;
  }
  if (persona == SeekerPersona.professional) {
    final location = DublinLocationContext.fromSession(session);
    return location == DublinLocationContext.arrivingSoon ||
        session?['pre_arrival_seeker'] == true;
  }
  return false;
}

VerificationGatewayLayout verificationGatewayLayoutForSession(
  Map<String, dynamic>? session,
) {
  final persona = SeekerPersona.fromSession(session);

  switch (persona) {
    case SeekerPersona.student:
      return const VerificationGatewayLayout(
        subtitle:
            'Tailored for Students. Verify with your university inbox, or '
            'continue if you do not have a university email yet.',
        recommended: VerificationGatewayPath.universityEmailOtp,
        alternates: [
          VerificationGatewayPath.offerLetterUpload,
        ],
      );
    case SeekerPersona.family:
      return _professionalFamilyLayout.copyWithSubtitle(
        'Tailored for Families. Complete LinkedIn or employment verification '
        'to become a Verified User.',
      );
    case SeekerPersona.relocating:
      return _professionalFamilyLayout.copyWithSubtitle(
        'Tailored for Relocating Professionals. Complete LinkedIn or '
        'employment verification to become a Verified User.',
      );
    case SeekerPersona.professional:
      if (isInboundRelocationPersona(session)) {
        return _professionalFamilyLayout.copyWithSubtitle(
          'Tailored for Inbound Professionals. Complete LinkedIn or '
          'employment verification to become a Verified User.',
        );
      }
      return _professionalFamilyLayout.copyWithSubtitle(
        'Tailored for Working Professionals. Complete LinkedIn or '
        'employment verification to become a Verified User.',
      );
    case null:
      return _professionalFamilyLayout;
  }
}

VerificationGatewayLabel getVerificationLabel(Map<String, dynamic>? session) {
  final layout = verificationGatewayLayoutForSession(session);
  final def = verificationGatewayCatalog[layout.recommended]!;
  final persona = SeekerPersona.fromSession(session);

  final personaName = switch (persona) {
    SeekerPersona.student => 'Student',
    SeekerPersona.professional => 'Working Professional',
    SeekerPersona.relocating => 'Relocating Professional',
    SeekerPersona.family => 'Family',
    null => 'Seeker',
  };

  if (layout.recommended == VerificationGatewayPath.inboundRelocation) {
    return inboundRelocationVerificationLabel;
  }

  return VerificationGatewayLabel(
    personaDisplayName: personaName,
    path: layout.recommended,
    pathTitle: def.pathTitle,
    suffixTag: layout.recommended == VerificationGatewayPath.universityEmailOtp
        ? 'Recommended'
        : '',
    description: def.description,
    route: def.route,
    icon: def.icon,
    leadingEmoji: def.leadingEmoji,
  );
}

const verificationGatewayCatalog =
    <VerificationGatewayPath, VerificationGatewayPathDefinition>{
  VerificationGatewayPath.universityEmailOtp: VerificationGatewayPathDefinition(
    pathTitle: 'I have a university email',
    description: 'Verify with your university inbox.',
    route: '/verify/id/university-email',
    icon: Icons.school_outlined,
    leadingEmoji: '🎓',
  ),
  VerificationGatewayPath.offerLetterUpload: VerificationGatewayPathDefinition(
    pathTitle: "I don't have a university email yet",
    description:
        'For students relocating to Dublin before university accounts are issued.',
    route: '/verify/pre-arrival',
    icon: Icons.description_outlined,
    leadingEmoji: '📄',
  ),
  VerificationGatewayPath.linkedInCorporate: VerificationGatewayPathDefinition(
    pathTitle: 'LinkedIn',
    description: 'Connect LinkedIn to verify your professional identity.',
    route: '/verify/social',
    icon: Icons.work_outline_rounded,
    leadingEmoji: '💼',
  ),
  VerificationGatewayPath.employmentContractUpload:
      VerificationGatewayPathDefinition(
    pathTitle: 'Employment verification',
    description: 'Upload your signed offer letter or employment contract.',
    route: '/verify/social',
    icon: Icons.upload_file_outlined,
    leadingEmoji: '📝',
  ),
  // Dormant Phase 1 — keep for reactivation; not listed in gateway layouts.
  VerificationGatewayPath.openBanking: VerificationGatewayPathDefinition(
    pathTitle: 'Instant Bank Link (Open Banking)',
    description: 'Link your Irish/EU bank account via secure Open Banking.',
    route: '/verify/open-banking',
    icon: Icons.account_balance_rounded,
    leadingEmoji: '🏦',
  ),
  VerificationGatewayPath.inboundRelocation: VerificationGatewayPathDefinition(
    pathTitle: 'Inbound Relocation Verification',
    description:
        'Securely upload your employment contract or letter of offer, or '
        'connect LinkedIn, to verify before you land.',
    route: '/verify/social',
    icon: Icons.upload_file_outlined,
    leadingEmoji: '✈️',
  ),
};

List<VerificationGatewayPath> alternateVerificationPaths(
  VerificationGatewayPath recommended, {
  Map<String, dynamic>? session,
}) {
  if (session != null) {
    return verificationGatewayLayoutForSession(session).alternates;
  }
  return VerificationGatewayPath.values
      .where((path) => path != recommended)
      .where((path) => !phase1DormantVerificationPaths.contains(path))
      .toList();
}
