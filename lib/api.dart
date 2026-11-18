import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class LensException implements Exception {
  LensException(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => message;
}

/// Client for the Stash Lens server (app.py). The phone talks to Stash Lens, never to Stash directly.
class LensApi {
  LensApi(String url, this.password) : base = normalize(url);

  final String base;
  final String password;

  static String normalize(String u) {
    var s = u.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Stash Lens uses HTTP Basic: any user name, the access password as the password.
  Map<String, String> get headers =>
      password.isEmpty ? const {} : {'Authorization': 'Basic ${base64Encode(utf8.encode(':$password'))}'};

  // ───────── tiny response cache so rails don't refetch while scrolling ─────────
  final Map<String, (DateTime, dynamic)> _cache = {};
  void clearCache() => _cache.clear();

  Uri _uri(String path, [Map<String, dynamic>? q]) {
    final qp = <String, String>{};
    q?.forEach((k, v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isEmpty) return;
      qp[k] = s;
    });
    return Uri.parse('$base/api/$path').replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? q, bool cache = true]) async {
    final uri = _uri(path, q);
    final key = uri.toString();
    final hit = _cache[key];
    if (cache && hit != null && DateTime.now().difference(hit.$1).inSeconds < 90) return hit.$2;
    final http.Response res;
    try {
      res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 45));
    } catch (_) {
      throw LensException('Could not reach Stash Lens at $base.\nIs it running, and is network access switched on?');
    }
    if (res.statusCode == 401) throw LensException('Wrong password.', code: 401);
    if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw LensException('Unexpected answer from the server (HTTP ${res.statusCode}).', code: res.statusCode);
    }
    if (res.statusCode >= 400) {
      final msg = body is Map && body['error'] != null ? body['error'].toString() : 'HTTP ${res.statusCode}';
      throw LensException(msg, code: res.statusCode);
    }
    if (cache) _cache[key] = (DateTime.now(), body);
    return body;
  }

  // ───────── URLs ─────────
  String img(String kind, int id, {int w = 480}) => '$base/api/img/$kind/$id?w=$w';
  String hero(int id) => '$base/api/hero/$id';
  String stream(int id, {int? fileId}) => '$base/api/stream/$id${fileId != null ? '?file=$fileId' : ''}';
  String sprite(int id) => '$base/api/sprite/$id';
  String preview(int id) => '$base/api/preview/$id';

  // ───────── endpoints ─────────
  Future<Map<String, dynamic>> status() async => (await get('status', null, false)) as Map<String, dynamic>;

  Future<Paged<Scene>> scenes(Map<String, dynamic> q) async {
    final d = await get('scenes', q) as Map<String, dynamic>;
    return Paged(
      (d['items'] as List).map((e) => Scene.fromJson(e as Map<String, dynamic>)).toList(),
      _int(d['total']),
      _int(d['pages']),
      active: (d['active'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<Scene> scene(int id) async => Scene.fromJson(await get('scenes/$id') as Map<String, dynamic>);

  Future<Paged<Performer>> performers(Map<String, dynamic> q) async {
    final d = await get('performers', q) as Map<String, dynamic>;
    return Paged(
      (d['items'] as List).map((e) => Performer.fromJson(e as Map<String, dynamic>)).toList(),
      _int(d['total']),
      _int(d['pages']),
      facets: (d['facets'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<Map<String, dynamic>> performer(int id) async => (await get('performers/$id')) as Map<String, dynamic>;

  Future<Paged<Studio>> studios(Map<String, dynamic> q) async {
    final d = await get('studios', q) as Map<String, dynamic>;
    return Paged((d['items'] as List).map((e) => Studio.fromJson(e as Map<String, dynamic>)).toList(), _int(d['total']), _int(d['pages']));
  }

  Future<Paged<TagItem>> tags(Map<String, dynamic> q) async {
    final d = await get('tags', q) as Map<String, dynamic>;
    return Paged(
      (d['items'] as List).map((e) => TagItem.fromJson(e as Map<String, dynamic>)).toList(),
      _int(d['total']),
      _int(d['pages']),
      extra: {'max_scenes': _int(d['max_scenes'], 1)},
    );
  }

  Future<Map<String, dynamic>> overview() async => (await get('overview')) as Map<String, dynamic>;

  Future<List<Scene>> onThisDay(String md, int y) async {
    final d = await get('onthisday', {'md': md, 'y': y}) as Map<String, dynamic>;
    return (d['items'] as List).map((e) => Scene.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Performer>> birthdays(String md, int y) async {
    final d = await get('birthdays', {'md': md, 'y': y}) as Map<String, dynamic>;
    return (d['items'] as List)
        .map((e) => Performer.fromJson(e as Map<String, dynamic>, note: (e as Map)['age'] != null ? 'Turns ${e['age']}' : null))
        .toList();
  }

  Future<Map<String, dynamic>?> spotlight() async => (await get('spotlight')) as Map<String, dynamic>?;

  Future<Map<String, String>> details(List<int> ids) async {
    if (ids.isEmpty) return {};
    final d = await get('details', {'ids': ids.join(',')}) as Map<String, dynamic>?;
    return (d ?? {}).map((k, v) => MapEntry(k, v.toString()));
  }

  /// Face framing (percent) for a scene's cast, for round portraits. Slow (face detection), so call lazily.
  Future<Map<int, (double, double)>> cast(int sceneId) async {
    try {
      final d = await get('cast/$sceneId', null, false) as Map<String, dynamic>?;
      final out = <int, (double, double)>{};
      for (final p in (d?['performers'] as List?) ?? const []) {
        final f = (p as Map)['face'] as Map?;
        if (f != null && f['x'] != null && f['y'] != null) {
          out[_int(p['id'])] = ((f['x'] as num).toDouble(), (f['y'] as num).toDouble());
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> scrub(int id) async {
    try {
      return (await get('scrub/$id')) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> health() async => (await get('health')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> duplicates() async => (await get('health/duplicates')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> missing() async => (await get('health/missing', null, false)) as Map<String, dynamic>;

  /// Reports resume point / played seconds back (only stored when "Sync with Stash" is on in Stash Lens).
  Future<void> progress(int id, {required double t, required double played, required bool play}) async {
    try {
      await http
          .post(
            _uri('progress/$id'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'t': t, 'played': played, 'play': play}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}

int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
