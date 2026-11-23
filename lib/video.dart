import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Snapshot of the playback state, shaped like the old video_player value so the UI code stays simple.
class LensVideoValue {
  const LensVideoValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.hasError = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedTo = Duration.zero,
    this.size = Size.zero,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool hasError;
  final Duration position;
  final Duration duration;
  final Duration bufferedTo;
  final Size size;

  double get aspectRatio => size.width > 0 && size.height > 0 ? size.width / size.height : 0;

  LensVideoValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? hasError,
    Duration? position,
    Duration? duration,
    Duration? bufferedTo,
    Size? size,
  }) {
    return LensVideoValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      hasError: hasError ?? this.hasError,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedTo: bufferedTo ?? this.bufferedTo,
      size: size ?? this.size,
    );
  }
}

/// A player built on libmpv (media_kit): plays practically any container and codec
/// (MKV, AVI, WMV, FLV, MPEG-TS, HEVC, AV1, VP9, old DivX/Xvid …), with hardware decoding when the phone
/// supports it and an automatic software fallback when it does not.
class LensVideo extends ValueNotifier<LensVideoValue> {
  LensVideo(this.url, {this.headers = const {}, int bufferMb = 32})
      : player = Player(configuration: PlayerConfiguration(bufferSize: bufferMb * 1024 * 1024)),
        super(const LensVideoValue()) {
    controller = VideoController(player);
  }

  final String url;
  final Map<String, String> headers;
  final Player player;
  late final VideoController controller;

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _dead = false;
  bool _completed = false;
  String? _err;

  void _set(LensVideoValue Function(LensVideoValue v) f) {
    if (_dead) return;
    value = f(value);
  }

  Future<void> initialize() async {
    final s = player.stream;
    _subs.addAll([
      s.error.listen((e) {
        _err = e.toString();
        if (value.isInitialized) _set((v) => v.copyWith(hasError: true));
      }),
      s.duration.listen((d) => _set((v) => v.copyWith(duration: d))),
      s.position.listen((p) {
        if (_completed) return;
        _set((v) => v.copyWith(position: p));
      }),
      s.buffer.listen((b) => _set((v) => v.copyWith(bufferedTo: b))),
      s.buffering.listen((b) => _set((v) => v.copyWith(isBuffering: b))),
      s.playing.listen((p) {
        if (p) _completed = false;
        _set((v) => v.copyWith(isPlaying: p));
      }),
      s.completed.listen((c) {
        _completed = c;
        if (c) _set((v) => v.copyWith(isPlaying: false, position: v.duration));
      }),
      s.width.listen((_) => _syncSize()),
      s.height.listen((_) => _syncSize()),
    ]);

    await player.open(Media(url, httpHeaders: headers), play: false);

    // Wait until mpv knows the length and the picture size (or fails).
    final sw = Stopwatch()..start();
    while (true) {
      if (_dead) return;
      if (_err != null) throw _err!;
      final st = player.state;
      final hasVideo = (st.width ?? 0) > 0 && (st.height ?? 0) > 0;
      if (st.duration > Duration.zero && hasVideo) break;
      if (st.duration > Duration.zero && sw.elapsed > const Duration(seconds: 5)) break; // audio only
      if (sw.elapsed > const Duration(seconds: 45)) throw 'Timed out while opening the file.';
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    _syncSize();
    _set((v) => v.copyWith(isInitialized: true, duration: player.state.duration));
  }

  void _syncSize() {
    final w = player.state.width ?? 0, h = player.state.height ?? 0;
    if (w > 0 && h > 0) _set((v) => v.copyWith(size: Size(w.toDouble(), h.toDouble())));
  }

  Future<void> play() async {
    if (_completed) {
      _completed = false;
      await player.seek(Duration.zero);
    }
    await player.play();
  }

  Future<void> pause() => player.pause();

  Future<void> seekTo(Duration d) async {
    _completed = false;
    _set((v) => v.copyWith(position: d));
    await player.seek(d);
  }

  Future<void> setLooping(bool on) => player.setPlaylistMode(on ? PlaylistMode.single : PlaylistMode.none);

  /// 0.0 – 1.0
  Future<void> setVolume(double v) => player.setVolume((v * 100).clamp(0, 100).toDouble());

  Future<void> setPlaybackSpeed(double s) => player.setRate(s);

  @override
  void dispose() {
    if (_dead) return;
    _dead = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    player.dispose();
    super.dispose();
  }
}

/// The picture only. Gestures and controls are drawn by the screens.
class LensVideoView extends StatelessWidget {
  const LensVideoView(this.video, {super.key, this.fit = BoxFit.contain});
  final LensVideo video;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: video.controller,
      controls: NoVideoControls,
      fit: fit,
      fill: Colors.transparent,
      wakelock: false,
    );
  }
}
