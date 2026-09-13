import 'package:flutter/foundation.dart';

/// Requests a Home screen primary destination after a header tap.
enum HomePrimaryDestination { explore, applications }

final homePrimaryDestinationNotifier =
    ValueNotifier<HomePrimaryDestination?>(null);

void requestHomeApplicationsTab() {
  if (homePrimaryDestinationNotifier.value ==
      HomePrimaryDestination.applications) {
    homePrimaryDestinationNotifier.value = null;
  }
  homePrimaryDestinationNotifier.value = HomePrimaryDestination.applications;
}

void requestHomeExploreTab() {
  if (homePrimaryDestinationNotifier.value == HomePrimaryDestination.explore) {
    homePrimaryDestinationNotifier.value = null;
  }
  homePrimaryDestinationNotifier.value = HomePrimaryDestination.explore;
}
