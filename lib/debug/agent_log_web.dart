import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void agentLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, dynamic> data,
) {
  final payload = jsonEncode({
    'sessionId': '41df06',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'runId': 'pre-fix',
  });
  // #region agent log
  unawaited(
    html.HttpRequest.request(
      'http://127.0.0.1:7937/ingest/3104528a-dafa-4274-b754-34f2ed630895',
      method: 'POST',
      sendData: payload,
      requestHeaders: {
        'Content-Type': 'application/json',
        'X-Debug-Session-Id': '41df06',
      },
    ).catchError((Object _, StackTrace __) {
      // Debug ingest unavailable (offline server / browser network) — never crash UI.
      return html.HttpRequest();
    }),
  );
  // #endregion
}
