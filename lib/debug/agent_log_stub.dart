import 'dart:convert';
import 'dart:io';

void agentLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, dynamic> data,
) {
  try {
    final payload = jsonEncode({
      'sessionId': '41df06',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'runId': 'pre-fix',
    });
    File('debug-41df06.log')
        .writeAsStringSync('$payload\n', mode: FileMode.append);
  } catch (_) {}
}
