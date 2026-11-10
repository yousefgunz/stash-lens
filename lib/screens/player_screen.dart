import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../models.dart';
import '../stash_client.dart';
import '../theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.scene});
  final Scene scene;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final StashClient _client = context.read<AppState>().client!;
  VideoPlayerController? _c;
  bool _showUi = true;
  String? _error;
  double _speed = 1;
  Timer? _hide;
  Timer? _save;
  double _lastSaved = 0;
  double _bumpDir = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _init();
  }

  Future<void> _init() async {
    final url = widget.scene.stream;
    if (url == null) {
      setState(() => _error = 'This scene has no stream.');
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: _client.headers);
    try {
      await c.initialize();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start playback.\n$e');
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    if (widget.scene.resumeTime > 5) await c.seekTo(Duration(seconds: widget.scene.resumeTime.round()));
    _lastSaved = c.value.position.inMilliseconds / 1000;
    await c.play();
    setState(() => _c = c);
    _scheduleHide();
    _save = Timer.periodic(const Duration(seconds: 10), (_) => _saveActivity());
  }

  void _saveActivity() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inMilliseconds / 1000;
    final played = (pos - _lastSaved).clamp(0.0, 60.0);
    _lastSaved = pos;
    _client.saveActivity(widget.scene.id, resumeTime: pos, playDuration: played).catchError((_) {});
  }

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

  void _seekBy(int seconds) {
    final c = _c;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    final max = c.value.duration;
    c.seekTo(target < Duration.zero ? Duration.zero : (target > max ? max : target));
    setState(() => _bumpDir = seconds.sign.toDouble());
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _bumpDir = 0);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _save?.cancel();
    _saveActivity();
    _c?.dispose();
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Pal.dim)),
              ),
            )
          : c == null
              ? const Center(child: CircularProgressIndicator(color: Pal.ember))
              : Stack(fit: StackFit.expand, children: [
                  Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
                  Row(children: [
                    Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggleUi, onDoubleTap: () => _seekBy(-10))),
                    Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggleUi, onDoubleTap: () => _seekBy(10))),
                  ]),
                  if (_bumpDir != 0)
                    Align(
                      alignment: _bumpDir < 0 ? const Alignment(-0.6, 0) : const Alignment(0.6, 0),
                      child: Text(_bumpDir < 0 ? '−10s' : '+10s', style: display(34)),
                    ),
                  IgnorePointer(
                    ignoring: !_showUi,
                    child: AnimatedOpacity(
                      opacity: _showUi ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: _Controls(
                        controller: c,
                        title: widget.scene.title,
                        speed: _speed,
                        onSpeed: (s) {
                          c.setPlaybackSpeed(s);
                          setState(() => _speed = s);
                        },
                        onSeekBy: _seekBy,
                        onInteract: _scheduleHide,
                      ),
                    ),
                  ),
                ]),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.title,
    required this.speed,
    required this.onSpeed,
    required this.onSeekBy,
    required this.onInteract,
  });

  final VideoPlayerController controller;
  final String title;
  final double speed;
  final ValueChanged<double> onSpeed;
  final ValueChanged<int> onSeekBy;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xB3000000), Colors.transparent, Colors.transparent, Color(0xCC000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.25, 0.65, 1]),
      ),
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            PopupMenuButton<double>(
              initialValue: speed,
              color: Pal.raised,
              onSelected: onSpeed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('${speed}×', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => PopupMenuItem(value: s, child: Text('$s×'))).toList(),
            ),
          ]),
          const Spacer(),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, v, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 38, onPressed: () => onSeekBy(-10), icon: const Icon(Icons.replay_10_rounded)),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  v.isPlaying ? controller.pause() : controller.play();
                  onInteract();
                },
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Pal.ember),
                  child: v.isBuffering
                      ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                      : Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42, color: Colors.black),
                ),
              ),
              const SizedBox(width: 20),
              IconButton(iconSize: 38, onPressed: () => onSeekBy(10), icon: const Icon(Icons.forward_10_rounded)),
            ]),
          ),
          const Spacer(),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (_, v, __) {
              final total = v.duration.inMilliseconds.toDouble();
              final pos = v.position.inMilliseconds.toDouble().clamp(0.0, total <= 0 ? 1.0 : total);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  Text(fmtDuration(pos / 1000), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: Pal.ember,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Pal.ember,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        min: 0,
                        max: total <= 0 ? 1 : total,
                        value: pos,
                        onChanged: (x) {
                          controller.seekTo(Duration(milliseconds: x.round()));
                          onInteract();
                        },
                      ),
                    ),
                  ),
                  Text(fmtDuration(total / 1000), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.dim)),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }
}
