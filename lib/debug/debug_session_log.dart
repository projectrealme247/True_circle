import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// NDJSON debug logger for Cursor debug sessions (file: debug-41df06.log).
void debugSessionLog({
  required String location,
  required String message,
  required Map<String, dynamic> data,
  String hypothesisId = '',
  String runId = 'pre-fix',
}) {
  if (!kDebugMode) return;
  try {
    final line = jsonEncode({
      'sessionId': '41df06',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'data': data,
      if (hypothesisId.isNotEmpty) 'hypothesisId': hypothesisId,
      'runId': runId,
    });
    File('debug-41df06.log').writeAsStringSync(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}
