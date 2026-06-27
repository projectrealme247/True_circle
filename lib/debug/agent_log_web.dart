import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

void agentLog({
  required String location,
  required String message,
  required Map<String, Object?> data,
  required String hypothesisId,
  String runId = 'pre-fix',
}) {
  final payload = jsonEncode({
    'sessionId': 'f79c8e',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });
  try {
    final xhr = web.XMLHttpRequest();
    xhr.open(
      'POST',
      'http://127.0.0.1:7937/ingest/3104528a-dafa-4274-b754-34f2ed630895',
    );
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('X-Debug-Session-Id', 'f79c8e');
    xhr.send(payload.toJS);
  } catch (_) {}
}
