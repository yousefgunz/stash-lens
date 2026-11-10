class Scene {
  Scene({
    required this.id,
    required this.title,
    this.date,
    this.rating100,
    this.resumeTime = 0,
    this.duration = 0,
    this.width = 0,
    this.height = 0,
    this.screenshot,
    this.preview,
    this.stream,
    this.studio,
    this.performers = const [],
    this.tags = const [],
    this.playCount = 0,
    this.details,
  });

  final String id;
  final String title;
  final String? date;
  int? rating100;
  final double resumeTime;
  final double duration;
  final int width;
  final int height;
  final String? screenshot;
  final String? preview;
  final String? stream;
  final String? studio;
  final List<Performer> performers;
  final List<String> tags;
  final int playCount;
  final String? details;

  double get progress => duration > 0 ? (resumeTime / duration).clamp(0.0, 1.0) : 0;

  String get quality {
    final h = height;
    if (h >= 2000) return '4K';
    if (h >= 1000) return '1080p';
    if (h >= 700) return '720p';
    if (h > 0) return '${h}p';
    return '';
  }

  factory Scene.fromJson(Map<String, dynamic> j) {
    final files = (j['files'] as List?) ?? const [];
    final f = files.isNotEmpty ? files.first as Map<String, dynamic> : <String, dynamic>{};
    final paths = (j['paths'] as Map<String, dynamic>?) ?? const {};
    final rawTitle = (j['title'] as String?)?.trim() ?? '';
    final title = rawTitle.isNotEmpty ? rawTitle : ((f['basename'] as String?) ?? 'Scene ${j['id']}');
    return Scene(
      id: j['id'].toString(),
      title: title,
      date: j['date'] as String?,
      rating100: j['rating100'] as int?,
      resumeTime: (j['resume_time'] as num?)?.toDouble() ?? 0,
      duration: (f['duration'] as num?)?.toDouble() ?? 0,
      width: (f['width'] as num?)?.toInt() ?? 0,
      height: (f['height'] as num?)?.toInt() ?? 0,
      screenshot: paths['screenshot'] as String?,
      preview: paths['preview'] as String?,
      stream: paths['stream'] as String?,
      studio: (j['studio'] as Map<String, dynamic>?)?['name'] as String?,
      performers: ((j['performers'] as List?) ?? const [])
          .map((p) => Performer.fromJson(p as Map<String, dynamic>))
          .toList(),
      tags: ((j['tags'] as List?) ?? const []).map((t) => (t as Map<String, dynamic>)['name'].toString()).toList(),
      playCount: (j['play_count'] as num?)?.toInt() ?? 0,
      details: j['details'] as String?,
    );
  }
}

class Performer {
  Performer({required this.id, required this.name, this.image, this.sceneCount = 0, this.favorite = false});

  final String id;
  final String name;
  final String? image;
  final int sceneCount;
  final bool favorite;

  factory Performer.fromJson(Map<String, dynamic> j) => Performer(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? 'Unknown',
        image: j['image_path'] as String?,
        sceneCount: (j['scene_count'] as num?)?.toInt() ?? 0,
        favorite: (j['favorite'] as bool?) ?? false,
      );
}

class Paged<T> {
  Paged(this.items, this.total);
  final List<T> items;
  final int total;
}

String fmtDuration(double seconds) {
  final s = seconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}
