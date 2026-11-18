import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

class ProgEntry {
  ProgEntry(this.id, this.t, this.d, this.u);
  final int id;
  final int t;
  final int d;
  final int u;
}

class AppState extends ChangeNotifier {
  LensApi? api;
  bool loaded = false;
  String savedUrl = '';
  String savedPassword = '';
  bool autoplayNext = true;
  Map<String, dynamic> status = {};
  Map<String, ProgEntry> _prog = {};
  SharedPreferences? _p;

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    savedUrl = p.getString('url') ?? '';
    savedPassword = p.getString('pw') ?? '';
    autoplayNext = p.getBool('autoplay') ?? true;
    try {
      final raw = jsonDecode(p.getString('prog') ?? '{}') as Map<String, dynamic>;
      _prog = raw.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, ProgEntry(int.parse(k), m['t'] as int, (m['d'] ?? 0) as int, m['u'] as int));
      });
    } catch (_) {
      _prog = {};
    }
    if (savedUrl.isNotEmpty) {
      api = LensApi(savedUrl, savedPassword);
      api!.status().then((s) {
        status = s;
        notifyListeners();
      }).catchError((_) {});
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> connect(String url, String password) async {
    final a = LensApi(url, password);
    final s = await a.status(); // throws LensException
    final p = _p ?? await SharedPreferences.getInstance();
    await p.setString('url', a.base);
    await p.setString('pw', password);
    savedUrl = a.base;
    savedPassword = password;
    api = a;
    status = s;
    notifyListeners();
  }

  void disconnect() {
    api = null;
    notifyListeners();
  }

  void setAutoplay(bool v) {
    autoplayNext = v;
    _p?.setBool('autoplay', v);
    notifyListeners();
  }

  // ───────── local watch progress (feeds "Continue watching") ─────────
  ProgEntry? progOf(int id) => _prog['$id'];

  List<ProgEntry> progList() {
    final l = _prog.values.toList()..sort((a, b) => b.u.compareTo(a.u));
    return l;
  }

  void setProg(int id, double t, double d) {
    if (t < 30 || (d > 0 && t > d * .95)) {
      _prog.remove('$id');
    } else {
      _prog['$id'] = ProgEntry(id, t.floor(), d.floor(), DateTime.now().millisecondsSinceEpoch);
    }
    if (_prog.length > 60) {
      final l = progList();
      for (final e in l.skip(60)) {
        _prog.remove('${e.id}');
      }
    }
    _p?.setString(
      'prog',
      jsonEncode(_prog.map((k, e) => MapEntry(k, {'t': e.t, 'd': e.d, 'u': e.u}))),
    );
    api?.clearCache(); // so Continue watching refreshes
    notifyListeners();
  }
}
