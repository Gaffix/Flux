import 'package:shared_preferences/shared_preferences.dart';

const serverUrlKey = 'flux_server_url';
const legacyServerUrlKey = 'server_url';
const defaultServerUrl = 'http://127.0.0.1:9000';

String normalizeServerUrl(String value) {
  var url = value.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

Future<String> getConfiguredServerUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final configured = prefs.getString(serverUrlKey) ?? prefs.getString(legacyServerUrlKey);
  final url = normalizeServerUrl(configured ?? defaultServerUrl);
  if (configured != null && configured != url) {
    await setConfiguredServerUrl(url);
  }
  return url;
}

Future<void> setConfiguredServerUrl(String value) async {
  final url = normalizeServerUrl(value);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(serverUrlKey, url);
  // Keep the old key in sync for already-installed versions during migration.
  await prefs.setString(legacyServerUrlKey, url);
}
