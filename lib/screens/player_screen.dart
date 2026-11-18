import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Native player for Stash Lens streams (/api/stream/<id>): chapters, scrub thumbnails, resume, up-next, progress sync.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.scene, this.startAt, this.fileId, this.queue = const []});
  final Scene scene;
  final double? startAt;
  final int? fileId;
  final List<Scene> queue;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AppState _app;
  late final LensApi _api;

  Scene? _detail;
  VideoPlayerController? _c;
  String? _error;
  bool _showUi = true;
  bool _landscapeLock = false;
  double _speed = 1;
  int? _fileId;
  Timer? _hide;
  double _bump = 0;
  Timer? _bumpT;

  // scrub sprite
  List<List<num>> _cues = [];
  double _spriteW = 0, _spriteH = 0;

  // progress reporting
  double _pend = 0, _acc = 0;
  double? _lastPos;
  int _lastSave = 0, _lastSend = 0;
  bool _counted = false;

  // up next
  bool _nextDismissed = false;
  bool _navigatedNext = false;

  Scene get _scene => _detail ?? widget.scene;
  Scene? get _next {
    for (final s in widget.queue) {
      if (s.id != widget.scene.id) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _api = _app.api!;
    _fileId = widget.fileId;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _init();
  }

  Future<void> _init() async {
    setState(() => _error = null);
    try {
      _detail = widget.scene.detailed ? widget.scene : await _api.scene(widget.scene.id);
    } catch (e) {
      // The details are optional for playback; carry on with what we have.
    }
    _api.scrub(widget.scene.id).then((d) {
      if (d == null || !mounted) return;
      setState(() {
        _cues = ((d['cues'] as List?) ?? const []).map((c) => (c as List).cast<num>()).toList();
        _spriteW = (d['w'] as num?)?.toDouble() ?? 0;
        _spriteH = (d['h'] as num?)?.toDouble() ?? 0;
      });
    });

    final c = VideoPlayerController.networkUrl(Uri.parse(_api.stream(widget.scene.id, fileId: _fileId)), httpHeaders: _api.headers);
    try {
      await c.initialize();
    } catch (e) {
      c.dispose();
      if (mounted) {
        setState(() => _error = 'This video could not be played.\n\nThe file may use a codec your phone cannot decode (for example HEVC/AV1 on older devices), '
            'or Stash Lens cannot reach the file.\n\n$e');
      }
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    final dur = c.value.duration.inMilliseconds / 1000;
    var start = widget.startAt ?? _savedPosition();
    if (start < 5 || (dur > 0 && start > dur - 10)) start = 0;
    if (start > 0) await c.seekTo(Duration(milliseconds: (start * 1000).round()));
    c.addListener(_onTick);
    await c.setPlaybackSpeed(_speed);
    await c.play();
    setState(() => _c = c);
    _scheduleHide();
  }

  double _savedPosition() {
    final local = _app.progOf(widget.scene.id)?.t.toDouble() ?? 0;
    final remote = _scene.resumeTime;
    return local > remote ? local : remote;
  }

  // ───────── progress / up next ─────────
  void _onTick() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inMilliseconds / 1000;
    final dur = c.value.duration.inMilliseconds / 1000;
    if (_lastPos != null && c.value.isPlaying) {
      final dt = pos - _lastPos!;
      if (dt > 0 && dt < 2.5) {
        _pend += dt;
        _acc += dt;
      }
    }
    _lastPos = pos;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSave > 5000) {
      _lastSave = now;
      _app.setProg(widget.scene.id, pos, dur);
    }
    if (now - _lastSend > 15000 && _pend > 0) {
      _lastSend = now;
      _flush();
    }
    // end of video → next
    if (dur > 0 && pos >= dur - 0.4 && !c.value.isPlaying && !_navigatedNext) {
      _flush();
      final n = _next;
      if (n != null && _app.autoplayNext && !_nextDismissed) {
        _navigatedNext = true;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlayerScreen(scene: n, startAt: 0, queue: widget.queue)));
      } else if (mounted) {
        setState(() => _showUi = true);
      }
    }
    // keep the up-next card ticking
    if (dur > 0 && dur - pos <= 15 && _next != null) {
      if (mounted) setState(() {});
    }
  }

  void _flush() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inMilliseconds / 1000;
    final dur = c.value.duration.inMilliseconds / 1000;
    if (dur <= 0) return;
    final play = !_counted && _acc >= (dur * .2 < 30 ? dur * .2 : 30);
    if (play) _counted = true;
    final t = (pos >= 30 && pos < dur * .95) ? pos.floorToDouble() : 0.0;
    final played = (_pend * 10).round() / 10;
    _pend = 0;
    if (played <= 0 && !play) return;
    _api.progress(widget.scene.id, t: t, played: played, play: play);
  }

  // ───────── UI helpers ─────────
  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && (_c?.value.isPlaying ?? false)) setState(() => _showUi = false);
    });
  }

  void _toggleUi() {
    setState(() => _showUi = !_showUi);
    if (_showUi) _scheduleHide();
  }

  void _seekBy(int secs) {
    final c = _c;
    if (c == null) return;
    var t = c.value.position + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (t > c.value.duration) t = c.value.duration;
    c.seekTo(t);
    setState(() => _bump = secs.sign.toDouble());
    _bumpT?.cancel();
    _bumpT = Timer(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _bump = 0);
    });
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      _flush();
    } else {
      c.play();
    }
    _scheduleHide();
  }

  void _toggleRotate() {
    setState(() => _landscapeLock = !_landscapeLock);
    SystemChrome.setPreferredOrientations(_landscapeLock ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : DeviceOrientation.values);
  }

  void _chapters() {
    final ms = _scene.markers;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text('Chapters', style: heading(22)),
          const SizedBox(height: 8),
          if (ms.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('This scene has no markers.', style: TextStyle(color: Pal.mute))),
          for (final m in ms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(fmtTime(m.seconds), style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.a2)),
              title: Text(m.title.isEmpty ? (m.tag ?? 'Marker') : m.title),
              subtitle: m.tag != null && m.title.isNotEmpty ? Text(m.tag!, style: const TextStyle(color: Pal.dim)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _c?.seekTo(Duration(milliseconds: (m.seconds * 1000).round()));
              },
            ),
        ]),
      ),
    );
  }

  void _versions() {
    final files = _scene.files;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text('Version', style: heading(22)),
          const SizedBox(height: 8),
          for (final f in files)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${f.res ?? '${f.height}p'} · ${(f.vcodec ?? '').toUpperCase()}'),
              subtitle: Text('${fmtSize(f.size)}${f.primary ? '  ·  default' : ''}', style: const TextStyle(color: Pal.dim)),
              trailing: (_fileId == null && f.primary) || _fileId == f.id ? const Icon(Icons.check_rounded, color: Pal.a) : null,
              onTap: () async {
                Navigator.pop(ctx);
                final pos = (_c?.value.position.inMilliseconds ?? 0) / 1000;
                await _swap(f.primary ? null : f.id, pos);
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _swap(int? fileId, double pos) async {
    _flush();
    final old = _c;
    old?.removeListener(_onTick);
    setState(() {
      _c = null;
      _fileId = fileId;
    });
    await old?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(_api.stream(widget.scene.id, fileId: fileId)), httpHeaders: _api.headers);
    try {
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.seekTo(Duration(milliseconds: (pos * 1000).round()));
      c.addListener(_onTick);
      await c.setPlaybackSpeed(_speed);
      await c.play();
      setState(() => _c = c);
    } catch (e) {
      c.dispose();
      if (mounted) setState(() => _error = 'That version could not be played.\n\n$e');
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _bumpT?.cancel();
    final c = _c;
    if (c != null && c.value.isInitialized) {
      final pos = c.value.position.inMilliseconds / 1000;
      final dur = c.value.duration.inMilliseconds / 1000;
      _app.setProg(widget.scene.id, pos, dur);
      _flush();
      c.removeListener(_onTick);
    }
    c?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? SafeArea(
              child: Stack(children: [
                Align(alignment: Alignment.topLeft, child: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded))),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, color: Pal.a, size: 44),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Pal.mute, height: 1.4)),
                      const SizedBox(height: 18),
                      GhostButton(label: 'Try again', icon: Icons.refresh_rounded, onTap: _init, height: 44),
                    ]),
                  ),
                ),
              ]),
            )
          : c == null
              ? Stack(children: [
                  const Center(child: Spin()),
                  SafeArea(child: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded))),
                ])
              : Stack(fit: StackFit.expand, children: [
                  Center(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c))),
                  Row(children: [
                    Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggleUi, onDoubleTap: () => _seekBy(-10))),
                    Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggleUi, onDoubleTap: () => _seekBy(10))),
                  ]),
                  if (_bump != 0)
                    IgnorePointer(
                      child: Align(
                        alignment: _bump < 0 ? const Alignment(-0.55, 0) : const Alignment(0.55, 0),
                        child: Text(_bump < 0 ? '−10s' : '+10s', style: heading(34)),
                      ),
                    ),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: c,
                    builder: (_, v, __) => v.isBuffering && v.isPlaying ? const IgnorePointer(child: Center(child: Spin())) : const SizedBox.shrink(),
                  ),
                  _UpNext(controller: c, next: _next, enabled: _app.autoplayNext && !_nextDismissed, onDismiss: () => setState(() => _nextDismissed = true), onGo: () {
                    final n = _next;
                    if (n == null || _navigatedNext) return;
                    _navigatedNext = true;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlayerScreen(scene: n, startAt: 0, queue: widget.queue)));
                  }),
                  IgnorePointer(
                    ignoring: !_showUi,
                    child: AnimatedOpacity(
                      opacity: _showUi ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: _Controls(
                        controller: c,
                        title: _scene.title,
                        speed: _speed,
                        hasChapters: _scene.markers.isNotEmpty,
                        hasVersions: _scene.files.length > 1,
                        markers: _scene.markers,
                        autoplay: _app.autoplayNext,
                        landscapeLock: _landscapeLock,
                        api: _api,
                        sceneId: widget.scene.id,
                        cues: _cues,
                        spriteW: _spriteW,
                        spriteH: _spriteH,
                        onSpeed: (s) {
                          c.setPlaybackSpeed(s);
                          setState(() => _speed = s);
                          _scheduleHide();
                        },
                        onSeekBy: _seekBy,
                        onToggle: _togglePlay,
                        onChapters: _chapters,
                        onVersions: _versions,
                        onRotate: _toggleRotate,
                        onAutoplay: () => setState(() => _app.setAutoplay(!_app.autoplayNext)),
                        onInteract: _scheduleHide,
                      ),
                    ),
                  ),
                ]),
    );
  }
}

// ───────────────────────────── up next ─────────────────────────────

class _UpNext extends StatelessWidget {
  const _UpNext({required this.controller, required this.next, required this.enabled, required this.onDismiss, required this.onGo});
  final VideoPlayerController controller;
  final Scene? next;
  final bool enabled;
  final VoidCallback onDismiss;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final n = next;
    final v = controller.value;
    final left = (v.duration - v.position).inMilliseconds / 1000;
    if (n == null || !enabled || v.duration == Duration.zero || left > 15 || left < 0) return const SizedBox.shrink();
    final api = apiOf(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 86),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xEE0E1016), borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 92, height: 52, child: LImage(api.img('scene', n.id, w: 300)))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('UP NEXT · ${left.ceil()}s', style: const TextStyle(color: Pal.a2, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
                ]),
              ),
              Column(children: [
                GestureDetector(onTap: onGo, child: const Icon(Icons.skip_next_rounded, size: 26)),
                const SizedBox(height: 4),
                GestureDetector(onTap: onDismiss, child: const Icon(Icons.close_rounded, size: 20, color: Pal.mute)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── controls ─────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.title,
    required this.speed,
    required this.hasChapters,
    required this.hasVersions,
    required this.markers,
    required this.autoplay,
    required this.landscapeLock,
    required this.api,
    required this.sceneId,
    required this.cues,
    required this.spriteW,
    required this.spriteH,
    required this.onSpeed,
    required this.onSeekBy,
    required this.onToggle,
    required this.onChapters,
    required this.onVersions,
    required this.onRotate,
    required this.onAutoplay,
    required this.onInteract,
  });

  final VideoPlayerController controller;
  final String title;
  final double speed;
  final bool hasChapters, hasVersions, autoplay, landscapeLock;
  final List<Marker> markers;
  final LensApi api;
  final int sceneId;
  final List<List<num>> cues;
  final double spriteW, spriteH;
  final ValueChanged<double> onSpeed;
  final ValueChanged<int> onSeekBy;
  final VoidCallback onToggle, onChapters, onVersions, onRotate, onAutoplay, onInteract;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xB3000000), Colors.transparent, Colors.transparent, Color(0xD9000000)], stops: [0, 0.25, 0.62, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
        ),
      ),
      SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
            if (hasChapters) IconButton(onPressed: onChapters, tooltip: 'Chapters', icon: const Icon(Icons.bookmarks_outlined)),
            if (hasVersions) IconButton(onPressed: onVersions, tooltip: 'Version', icon: const Icon(Icons.hd_outlined)),
            IconButton(onPressed: onAutoplay, tooltip: 'Autoplay next', icon: Icon(Icons.skip_next_rounded, color: autoplay ? Pal.a2 : Pal.dim)),
            PopupMenuButton<double>(
              initialValue: speed,
              onSelected: onSpeed,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${speed == speed.roundToDouble() ? speed.toInt() : speed}×', style: const TextStyle(fontWeight: FontWeight.w800))),
              itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) => PopupMenuItem(value: s, child: Text('$s×'))).toList(),
            ),
            IconButton(onPressed: onRotate, tooltip: 'Rotate', icon: Icon(landscapeLock ? Icons.screen_lock_landscape_rounded : Icons.screen_rotation_rounded)),
          ]),
          const Spacer(),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, v, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 40, onPressed: () => onSeekBy(-10), icon: const Icon(Icons.replay_10_rounded)),
              const SizedBox(width: 22),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(gradient: Pal.grad, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Pal.a.withOpacity(0.4), blurRadius: 24)]),
                  child: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(width: 22),
              IconButton(iconSize: 40, onPressed: () => onSeekBy(10), icon: const Icon(Icons.forward_10_rounded)),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SeekBar(controller: controller, markers: markers, api: api, sceneId: sceneId, cues: cues, spriteW: spriteW, spriteH: spriteH, onInteract: onInteract),
          ),
        ]),
      ),
    ]);
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.controller, required this.markers, required this.api, required this.sceneId, required this.cues, required this.spriteW, required this.spriteH, required this.onInteract});
  final VideoPlayerController controller;
  final List<Marker> markers;
  final LensApi api;
  final int sceneId;
  final List<List<num>> cues;
  final double spriteW, spriteH;
  final VoidCallback onInteract;
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag; // 0..1 while dragging

  List<num>? _cueAt(double t) {
    List<num>? best;
    for (final c in widget.cues) {
      if (c[0] <= t) {
        best = c;
      } else {
        break;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (_, v, __) {
        final dur = v.duration.inMilliseconds / 1000;
        final pos = v.position.inMilliseconds / 1000;
        final frac = _drag ?? (dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0);
        double buffered = 0;
        if (v.buffered.isNotEmpty && dur > 0) buffered = (v.buffered.last.end.inMilliseconds / 1000 / dur).clamp(0.0, 1.0);
        final shownT = frac * dur;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 40,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              double fromDx(double dx) => (dx / w).clamp(0.0, 1.0);
              final cue = _drag != null ? _cueAt(shownT) : null;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  widget.controller.seekTo(Duration(milliseconds: (fromDx(d.localPosition.dx) * dur * 1000).round()));
                  widget.onInteract();
                },
                onHorizontalDragStart: (d) => setState(() => _drag = fromDx(d.localPosition.dx)),
                onHorizontalDragUpdate: (d) => setState(() => _drag = fromDx(d.localPosition.dx)),
                onHorizontalDragEnd: (_) {
                  final f = _drag;
                  setState(() => _drag = null);
                  if (f != null) widget.controller.seekTo(Duration(milliseconds: (f * dur * 1000).round()));
                  widget.onInteract();
                },
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 18,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                      Container(height: 4, width: w * buffered, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                      Container(height: 4, width: w * frac, decoration: BoxDecoration(gradient: Pal.grad, borderRadius: BorderRadius.circular(2))),
                      if (dur > 0)
                        for (final m in widget.markers)
                          Positioned(left: (m.seconds / dur).clamp(0.0, 1.0) * w - 1.5, top: -3, child: Container(width: 3, height: 10, decoration: BoxDecoration(color: Pal.a2, borderRadius: BorderRadius.circular(2)))),
                      Positioned(left: w * frac - 7, top: -5, child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                    ]),
                  ),
                  if (_drag != null)
                    Positioned(
                      left: (w * frac - 70).clamp(0.0, (w - 140).clamp(0.0, double.infinity)),
                      bottom: 34,
                      child: _Thumb(api: widget.api, sceneId: widget.sceneId, cue: cue, spriteW: widget.spriteW, spriteH: widget.spriteH, time: shownT),
                    ),
                ]),
              );
            }),
          ),
          Row(children: [
            Text(fmtTime(shownT), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(fmtTime(dur), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Pal.mute)),
          ]),
        ]);
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.api, required this.sceneId, required this.cue, required this.spriteW, required this.spriteH, required this.time});
  final LensApi api;
  final int sceneId;
  final List<num>? cue;
  final double spriteW, spriteH;
  final double time;

  @override
  Widget build(BuildContext context) {
    Widget img = const SizedBox.shrink();
    double w = 140, h = 0;
    if (cue != null && cue!.length >= 5 && spriteW > 0) {
      final x = cue![1].toDouble(), y = cue![2].toDouble(), cw = cue![3].toDouble(), ch = cue![4].toDouble();
      final k = 140 / cw;
      w = 140;
      h = ch * k;
      img = SizedBox(
        width: w,
        height: h,
        child: ClipRect(
          child: Stack(children: [
            Positioned(
              left: -x * k,
              top: -y * k,
              width: spriteW * k,
              height: spriteH * k,
              child: CachedNetworkImage(imageUrl: api.sprite(sceneId), httpHeaders: api.headers, fit: BoxFit.fill),
            ),
          ]),
        ),
      );
    }
    return Container(
      width: w,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (h > 0) img,
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(fmtTime(time), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
      ]),
    );
  }
}
