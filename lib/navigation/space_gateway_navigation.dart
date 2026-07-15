import 'package:flutter/material.dart';

import 'navigate_after_identity.dart';

/// Routes authenticated users after login using [ActiveModeService] precedence.
Future<void> navigateAfterAuth(BuildContext context) async {
  await navigateAfterIdentity(context, force: true);
}
