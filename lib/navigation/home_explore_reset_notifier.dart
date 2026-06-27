import 'package:flutter/foundation.dart';

/// Bumps when the global logo requests a return to Explore tab (index 0).
final homeExploreResetNotifier = ValueNotifier<int>(0);

void requestHomeExploreReset() {
  homeExploreResetNotifier.value++;
}

/// Hard reset used by logo navigation — clears to Explore index 0.
void hardResetHomeExploreTab() {
  if (homeExploreResetNotifier.value == 0) {
    homeExploreResetNotifier.value = -1;
  }
  homeExploreResetNotifier.value = 0;
}
