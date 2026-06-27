import 'package:web/web.dart' as web;

void openOpenBankingConnection(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
