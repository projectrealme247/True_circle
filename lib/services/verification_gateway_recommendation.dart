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
}

const inboundRelocationVerificationLabel = VerificationGatewayLabel(
  personaDisplayName: 'Inbound Relocation',
  path: VerificationGatewayPath.inboundRelocation,
  pathTitle: 'Inbound Relocation Verification',
  suffixTag: '',
  description:
      'Securely upload your employment contract or letter of offer and link '
      'your financial accounts to instantly bypass local credit history '
      'friction before you land.',
  route: '/verify/social',
  icon: Icons.upload_file_outlined,
  leadingEmoji: '💼',
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
            'Tailored for Students. Complete your verification path below to upgrade your matching tier.',
        recommended: VerificationGatewayPath.universityEmailOtp,
        alternates: [
          VerificationGatewayPath.offerLetterUpload,
          VerificationGatewayPath.openBanking,
        ],
      );
    case SeekerPersona.family:
      return const VerificationGatewayLayout(
        subtitle:
            'Tailored for Families. Complete your verification path below to upgrade your matching tier.',
        recommended: VerificationGatewayPath.inboundRelocation,
        alternates: [
          VerificationGatewayPath.employmentContractUpload,
          VerificationGatewayPath.linkedInCorporate,
          VerificationGatewayPath.openBanking,
        ],
      );
    case SeekerPersona.relocating:
      return const VerificationGatewayLayout(
        subtitle:
            'Tailored for Relocating Professionals. Complete your verification path below to upgrade your matching tier.',
        recommended: VerificationGatewayPath.inboundRelocation,
        alternates: [
          VerificationGatewayPath.employmentContractUpload,
          VerificationGatewayPath.linkedInCorporate,
          VerificationGatewayPath.openBanking,
        ],
      );
    case SeekerPersona.professional:
      if (isInboundRelocationPersona(session)) {
        return const VerificationGatewayLayout(
          subtitle:
              'Tailored for Inbound Professionals. Complete your verification path below to upgrade your matching tier.',
          recommended: VerificationGatewayPath.inboundRelocation,
          alternates: [
            VerificationGatewayPath.employmentContractUpload,
            VerificationGatewayPath.linkedInCorporate,
            VerificationGatewayPath.openBanking,
          ],
        );
      }
      return const VerificationGatewayLayout(
        subtitle:
            'Tailored for Working Professionals. Complete your verification path below to upgrade your matching tier.',
        recommended: VerificationGatewayPath.linkedInCorporate,
        alternates: [
          VerificationGatewayPath.employmentContractUpload,
          VerificationGatewayPath.openBanking,
        ],
      );
    case null:
      return const VerificationGatewayLayout(
        subtitle:
            'Complete your verification path below to upgrade your matching tier.',
        recommended: VerificationGatewayPath.linkedInCorporate,
        alternates: [
          VerificationGatewayPath.openBanking,
        ],
      );
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
    pathTitle: 'University Email OTP',
    description:
        'Verify with your active university inbox for the strongest student signal.',
    route: '/verify/id/university-email',
    icon: Icons.school_outlined,
    leadingEmoji: '🎓',
  ),
  VerificationGatewayPath.offerLetterUpload: VerificationGatewayPathDefinition(
    pathTitle: 'Offer Letter / Document Uploader',
    description:
        'Upload an offer or enrollment letter before you land in Dublin.',
    route: '/verify/pre-arrival',
    icon: Icons.description_outlined,
    leadingEmoji: '📄',
  ),
  VerificationGatewayPath.linkedInCorporate: VerificationGatewayPathDefinition(
    pathTitle: 'LinkedIn OAuth',
    description: 'Connect LinkedIn to verify your professional identity.',
    route: '/verify/social',
    icon: Icons.work_outline_rounded,
    leadingEmoji: '💼',
  ),
  VerificationGatewayPath.employmentContractUpload:
      VerificationGatewayPathDefinition(
    pathTitle: 'Employment Contract Uploader',
    description: 'Upload your signed offer letter or employment contract.',
    route: '/verify/social',
    icon: Icons.upload_file_outlined,
    leadingEmoji: '📝',
  ),
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
        'Securely upload your employment contract or letter of offer and link '
        'your financial accounts to instantly bypass local credit history '
        'friction before you land.',
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
      .toList();
}
