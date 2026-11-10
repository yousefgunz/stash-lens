import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stash_client.dart';

class AppState extends ChangeNotifier {
  StashClient? client;
  bool loaded = false;
  String savedUrl = '';
  String savedKey = '';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    savedUrl = p.getString('url') ?? '';
    savedKey = p.getString('key') ?? '';
    if (savedUrl.isNotEmpty) client = StashClient(savedUrl, savedKey);
    loaded = true;
    notifyListeners();
  }

  Future<void> connect(String url, String key) async {
    final c = StashClient(url, key);
    await c.ping(); // throws StashException on failure
    final p = await SharedPreferences.getInstance();
    await p.setString('url', c.baseUrl);
    await p.setString('key', key.trim());
    savedUrl = c.baseUrl;
    savedKey = key.trim();
    client = c;
    notifyListeners();
  }

  void disconnect() {
    client = null;
    notifyListeners();
  }
}
