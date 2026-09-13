import '../config/market/dublin_commuter_hubs.dart';

/// Whether seeker onboarding has a mandatory, resolved destination.
///
/// Valid: preset hub or custom hub from search results.
/// Invalid: empty, typed-only text, unresolved query, null hub, legacy unknown.
bool isSeekerDestinationValid({
  required bool commuteDestinationUnknown,
  required DublinCommuterHub? hub,
}) {
  if (commuteDestinationUnknown) return false;
  return hub != null;
}
