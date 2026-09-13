import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../utils/json_safe.dart';

void agentLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, dynamic> data,
) {
  final payload = jsonEncode({
    'sessionId': 'd7a881',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': JsonSafe.encodeMap(data),
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'runId': 'post-fix',
  });
  unawaited(
    html.HttpRequest.request(
      'http://127.0.0.1:7937/ingest/3104528a-dafa-4274-b754-34f2ed630895',
      method: 'POST',
      sendData: payload,
      requestHeaders: {
        'Content-Type': 'application/json',
        'X-Debug-Session-Id': 'd7a881',
      },
    ).catchError((Object _, StackTrace __) {
      // Debug ingest unavailable (offline server / browser network) — never crash UI.
      return html.HttpRequest();
    }),
  );
}
