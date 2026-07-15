import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void propertyCardDebugLog(Map<String, Object?> payload) {
  final body = jsonEncode(payload);
  html.HttpRequest.request(
    'http://127.0.0.1:7937/ingest/3104528a-dafa-4274-b754-34f2ed630895',
    method: 'POST',
    sendData: body,
    requestHeaders: {
      'Content-Type': 'application/json',
      'X-Debug-Session-Id': '41df06',
    },
  );
}
