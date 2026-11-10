import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class StashException implements Exception {
  StashException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _sceneFields = '''
  id title date rating100 resume_time play_count details
  files { duration width height basename }
  paths { screenshot preview stream }
  studio { name }
  performers { id name image_path }
  tags { name }
''';

class StashClient {
  StashClient(String url, this.apiKey) : baseUrl = _normalize(url);

  final String baseUrl;
  final String apiKey;

  static String _normalize(String u) {
    var s = u.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Headers for images and video streams (Stash accepts the key as an `ApiKey` header).
  Map<String, String> get headers => {if (apiKey.isNotEmpty) 'ApiKey': apiKey};

  Future<Map<String, dynamic>> gql(String query, [Map<String, dynamic>? vars]) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$baseUrl/graphql'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'variables': vars ?? {}}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw StashException('Could not reach Stash at $baseUrl. Is the phone on the same network?');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw StashException('Stash rejected the API key.');
    }
    if (res.statusCode != 200) throw StashException('Stash answered with HTTP ${res.statusCode}.');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final errors = body['errors'] as List?;
    if (errors != null && errors.isNotEmpty) {
      throw StashException((errors.first as Map)['message'].toString());
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<String> ping() async {
    final d = await gql('{ version { version } }');
    return (d['version'] as Map)['version'].toString();
  }

  Future<Paged<Scene>> scenes({
    int page = 1,
    int perPage = 24,
    String sort = 'created_at',
    String direction = 'DESC',
    String? query,
    Map<String, dynamic>? sceneFilter,
  }) async {
    final d = await gql('''
      query(\$filter: FindFilterType, \$sf: SceneFilterType) {
        findScenes(filter: \$filter, scene_filter: \$sf) {
          count
          scenes { $_sceneFields }
        }
      }
    ''', {
      'filter': {
        'page': page,
        'per_page': perPage,
        'sort': sort,
        'direction': direction,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
      'sf': sceneFilter,
    });
    final r = d['findScenes'] as Map<String, dynamic>;
    return Paged(
      (r['scenes'] as List).map((e) => Scene.fromJson(e as Map<String, dynamic>)).toList(),
      (r['count'] as num).toInt(),
    );
  }

  Future<Scene> scene(String id) async {
    final d = await gql('query(\$id: ID!) { findScene(id: \$id) { $_sceneFields } }', {'id': id});
    return Scene.fromJson(d['findScene'] as Map<String, dynamic>);
  }

  Future<Paged<Performer>> performers({int page = 1, int perPage = 36, String? query, bool favoritesOnly = false}) async {
    final d = await gql('''
      query(\$filter: FindFilterType, \$pf: PerformerFilterType) {
        findPerformers(filter: \$filter, performer_filter: \$pf) {
          count
          performers { id name image_path scene_count favorite }
        }
      }
    ''', {
      'filter': {
        'page': page,
        'per_page': perPage,
        'sort': 'scenes_count',
        'direction': 'DESC',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
      'pf': favoritesOnly ? {'filter_favorites': true} : null,
    });
    final r = d['findPerformers'] as Map<String, dynamic>;
    return Paged(
      (r['performers'] as List).map((e) => Performer.fromJson(e as Map<String, dynamic>)).toList(),
      (r['count'] as num).toInt(),
    );
  }

  Future<void> saveActivity(String id, {required double resumeTime, required double playDuration}) async {
    await gql(
      'mutation(\$id: ID!, \$r: Float, \$d: Float) { sceneSaveActivity(id: \$id, resume_time: \$r, playDuration: \$d) }',
      {'id': id, 'r': resumeTime, 'd': playDuration},
    );
  }

  Future<void> setRating(String id, int? rating100) async {
    await gql(
      'mutation(\$input: SceneUpdateInput!) { sceneUpdate(input: \$input) { id } }',
      {
        'input': {'id': id, 'rating100': rating100},
      },
    );
  }
}
