import 'dart:convert';
import 'dart:io';

import '../utils/json_safe.dart';

void agentLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, dynamic> data,
) {
  try {
    final payload = jsonEncode({
      'sessionId': 'd7a881',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': JsonSafe.encodeMap(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'runId': 'post-fix',
    });
    File('debug-d7a881.log')
        .writeAsStringSync('$payload\n', mode: FileMode.append);
  } catch (_) {}
}
