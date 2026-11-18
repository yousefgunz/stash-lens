// Models for the Stash Lens JSON API (app.py).

num? _n(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);
int _i(dynamic v, [int d = 0]) => _n(v)?.toInt() ?? d;
double _d(dynamic v, [double d = 0]) => _n(v)?.toDouble() ?? d;
bool _b(dynamic v) => v == true || v == 1;

class Ref {
  Ref(this.id, this.name, {this.age});
  final int id;
  final String name;
  final int? age;
  factory Ref.fromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    return Ref(_i(m['id']), (m['name'] ?? '').toString(), age: _n(m['age'])?.toInt());
  }
}

class Marker {
  Marker(this.id, this.title, this.seconds, this.tag);
  final int id;
  final String title;
  final double seconds;
  final String? tag;
  factory Marker.fromJson(Map<String, dynamic> m) =>
      Marker(_i(m['id']), (m['title'] ?? '').toString(), _d(m['seconds']), m['tag']?.toString());
}

class SceneFile {
  SceneFile(this.id, this.basename, this.path, this.size, this.primary, this.format, this.width, this.height,
      this.duration, this.vcodec, this.acodec, this.fps, this.bitrate, this.res, this.fingerprints);
  final int id;
  final String basename;
  final String path;
  final int size;
  final bool primary;
  final String? format;
  final int width;
  final int height;
  final double duration;
  final String? vcodec;
  final String? acodec;
  final double fps;
  final int bitrate;
  final String? res;
  final List<String> fingerprints;
  factory SceneFile.fromJson(Map<String, dynamic> m) => SceneFile(
        _i(m['id']),
        (m['basename'] ?? '').toString(),
        (m['path'] ?? '').toString(),
        _i(m['size']),
        _b(m['is_primary']),
        m['format']?.toString(),
        _i(m['width']),
        _i(m['height']),
        _d(m['duration']),
        m['video_codec']?.toString(),
        m['audio_codec']?.toString(),
        _d(m['frame_rate']),
        _i(m['bit_rate']),
        m['res']?.toString(),
        ((m['fingerprints'] as List?) ?? const [])
            .map((f) => '${(f as Map)['type']}: ${f['value']}')
            .toList(),
      );
}

class Scene {
  Scene({
    required this.id,
    required this.title,
    this.date,
    this.rating,
    this.studioId,
    this.studio,
    this.organized = false,
    this.createdAt,
    this.size = 0,
    this.duration = 0,
    this.width = 0,
    this.height = 0,
    this.vcodec,
    this.oCount = 0,
    this.playCount = 0,
    this.path,
    this.res,
    this.performers = const [],
    this.tags = const [],
    // detail only
    this.details,
    this.director,
    this.code,
    this.resumeTime = 0,
    this.files = const [],
    this.markers = const [],
    this.oDates = const [],
    this.viewDates = const [],
    this.urls = const [],
    this.hero = false,
    this.detailed = false,
  });

  final int id;
  final String title;
  final String? date;
  final int? rating; // 0-100
  final int? studioId;
  final String? studio;
  final bool organized;
  final String? createdAt;
  final int size;
  final double duration;
  final int width;
  final int height;
  final String? vcodec;
  final int oCount;
  final int playCount;
  final String? path;
  final String? res;
  final List<Ref> performers;
  final List<Ref> tags;

  final String? details;
  final String? director;
  final String? code;
  final double resumeTime;
  final List<SceneFile> files;
  final List<Marker> markers;
  final List<String> oDates;
  final List<String> viewDates;
  final List<String> urls;
  final bool hero;
  final bool detailed;

  int get stars => ((rating ?? 0) / 20).round();
  String? get year => (date != null && date!.length >= 4) ? date!.substring(0, 4) : null;
  bool get isHigh => res == '8K' || res == '6K' || res == '4K';

  factory Scene.fromJson(Map<String, dynamic> j) {
    final detailed = j.containsKey('files');
    return Scene(
      id: _i(j['id']),
      title: (j['title'] ?? 'Scene ${j['id']}').toString(),
      date: j['date']?.toString(),
      rating: _n(j['rating'])?.toInt(),
      studioId: _n(j['studio_id'])?.toInt(),
      studio: j['studio']?.toString(),
      organized: _b(j['organized']),
      createdAt: j['created_at']?.toString(),
      size: _i(j['size']),
      duration: _d(j['duration']),
      width: _i(j['width']),
      height: _i(j['height']),
      vcodec: j['vcodec']?.toString(),
      oCount: _i(j['o_count']),
      playCount: _i(j['play_count']),
      path: j['path']?.toString(),
      res: j['res']?.toString(),
      performers: ((j['performers'] as List?) ?? const []).map(Ref.fromJson).toList(),
      tags: ((j['tags'] as List?) ?? const []).map(Ref.fromJson).toList(),
      details: j['details']?.toString(),
      director: j['director']?.toString(),
      code: j['code']?.toString(),
      resumeTime: _d(j['resume_time']),
      files: ((j['files'] as List?) ?? const []).map((f) => SceneFile.fromJson(f as Map<String, dynamic>)).toList(),
      markers: ((j['markers'] as List?) ?? const []).map((m) => Marker.fromJson(m as Map<String, dynamic>)).toList(),
      oDates: ((j['o_dates'] as List?) ?? const []).map((e) => e.toString()).toList(),
      viewDates: ((j['view_dates'] as List?) ?? const []).map((e) => e.toString()).toList(),
      urls: ((j['urls'] as List?) ?? const []).map((e) => e.toString()).toList(),
      hero: _b(j['hero']),
      detailed: detailed,
    );
  }
}

class Performer {
  Performer({
    required this.id,
    required this.name,
    this.disambiguation,
    this.gender,
    this.birthdate,
    this.country,
    this.ethnicity,
    this.height,
    this.favorite = false,
    this.rating,
    this.scenes = 0,
    this.oCount = 0,
    this.age,
    this.note,
  });

  final int id;
  final String name;
  final String? disambiguation;
  final String? gender;
  final String? birthdate;
  final String? country;
  final String? ethnicity;
  final int? height;
  final bool favorite;
  final int? rating;
  final int scenes;
  final int oCount;
  final int? age;
  final String? note;

  int get stars => ((rating ?? 0) / 20).round();

  factory Performer.fromJson(Map<String, dynamic> j, {String? note}) => Performer(
        id: _i(j['id']),
        name: (j['name'] ?? 'Unknown').toString(),
        disambiguation: j['disambiguation']?.toString(),
        gender: j['gender']?.toString(),
        birthdate: j['birthdate']?.toString(),
        country: j['country']?.toString(),
        ethnicity: j['ethnicity']?.toString(),
        height: _n(j['height'])?.toInt(),
        favorite: _b(j['favorite']),
        rating: _n(j['rating'])?.toInt(),
        scenes: _i(j['scenes']),
        oCount: _i(j['o_count']),
        age: _n(j['age'])?.toInt(),
        note: note ?? (j['age'] != null && j['turns'] == true ? 'Turns ${j['age']}' : null),
      );
}

class Studio {
  Studio(this.id, this.name, this.parent, this.favorite, this.rating, this.scenes, this.oCount, this.duration);
  final int id;
  final String name;
  final String? parent;
  final bool favorite;
  final int? rating;
  final int scenes;
  final int oCount;
  final double duration;
  factory Studio.fromJson(Map<String, dynamic> j) => Studio(
        _i(j['id']),
        (j['name'] ?? '').toString(),
        j['parent']?.toString(),
        _b(j['favorite']),
        _n(j['rating'])?.toInt(),
        _i(j['scenes']),
        _i(j['o_count']),
        _d(j['duration']),
      );
}

class TagItem {
  TagItem(this.id, this.name, this.favorite, this.scenes, this.performers);
  final int id;
  final String name;
  final bool favorite;
  final int scenes;
  final int performers;
  factory TagItem.fromJson(Map<String, dynamic> j) =>
      TagItem(_i(j['id']), (j['name'] ?? '').toString(), _b(j['favorite']), _i(j['scenes']), _i(j['performers']));
}

class Paged<T> {
  Paged(this.items, this.total, this.pages, {this.active = const {}, this.facets = const {}, this.extra = const {}});
  final List<T> items;
  final int total;
  final int pages;
  final Map<String, dynamic> active;
  final Map<String, dynamic> facets;
  final Map<String, dynamic> extra;
}

// ───────────── formatting helpers ─────────────

String fmtTime(double seconds) {
  final s = seconds.isFinite ? seconds.round() : 0;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

String fmtHours(double seconds) {
  final h = seconds / 3600;
  if (h >= 100) return '${h.round()} h';
  if (h >= 1) return '${h.toStringAsFixed(1)} h';
  return '${(seconds / 60).round()} min';
}

String fmtSize(num bytes) {
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i >= 3 ? 1 : 0)} ${u[i]}';
}

String fmtNum(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
