import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../video.dart';
import '../widgets.dart';

class _FeedMode {
  const _FeedMode(this.label, this.params);
  final String label;
  final Map<String, dynamic> params;
}

const _modes = <_FeedMode>[
  _FeedMode('For you', {'sort': 'random'}),
  _FeedMode('Favourites', {'sort': 'random', 'flag': 'favorites'}),
  _FeedMode('Unwatched', {'sort': 'random', 'flag': 'unplayed'}),
  _FeedMode('Top rated', {'sort': 'rating', 'dir': 'desc'}),
  _FeedMode('New', {'sort': 'created', 'dir': 'desc'}),
  _FeedMode('4K+', {'sort': 'random', 'res': '4K'}),
];

/// TikTok-style vertical feed: one scene per screen, swipe up for the next, autoplaying.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.active});
  final bool active;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  final _pc = PageController();
  final _items = <Scene>[];
  final _seen = <int>{};
  final _ctrls = <int, LensVideo>{};
  final _failed = <int>{};
  int _mode = 0;
  int _cur = 0;
  int _pageNo = 0;
  int _pages = 1;
  bool _loading = false;
  String? _error;
  bool _away = false; // a route is open above the feed
  bool _paused = false; // user tapped pause
  bool _appActive = true;
  int _gen = 0; // bumps on filter change so stale loads are ignored

  bool get _shouldPlay => widget.active && !_away && !_paused && _appActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _more();
  }

  @override
  void didUpdateWidget(FeedScreen old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _appActive = s == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    _pc.dispose();
    super.dispose();
  }

  void _sync() {
    final c = _ctrls[_cur];
    if (c == null || !c.value.isInitialized) return;
    if (_shouldPlay) {
      c.play();
    } else {
      c.pause();
    }
    if (mounted) setState(() {});
  }

  Future<void> _more() async {
    if (_loading || _pageNo >= _pages && _pageNo != 0) return;
    final gen = _gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = apiOf(context);
      final r = await api.scenes({..._modes[_mode].params, 'per': 12, 'page': _pageNo + 1});
      if (!mounted || gen != _gen) return;
      _pageNo++;
      _pages = r.pages;
      var added = 0;
      for (final s in r.items) {
        if (_seen.add(s.id)) {
          _items.add(s);
          added++;
        }
      }
      setState(() => _loading = false);
      // random sort repeats across pages: if a page was all duplicates, try the next one
      if (added == 0 && _pageNo < _pages) {
        _more();
        return;
      }
      _windowControllers();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _setMode(int m) {
    if (m == _mode) return;
    _gen++;
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    _failed.clear();
    setState(() {
      _mode = m;
      _items.clear();
      _seen.clear();
      _cur = 0;
      _pageNo = 0;
      _pages = 1;
      _loading = false;
      _paused = false;
    });
    if (_pc.hasClients) _pc.jumpToPage(0);
    _more();
  }

  /// Keep live players only for the current page and its neighbours.
  void _windowControllers() {
    if (!mounted) return;
    final keep = {_cur - 1, _cur, _cur + 1}..removeWhere((i) => i < 0 || i >= _items.length);
    for (final i in _ctrls.keys.toList()) {
      if (!keep.contains(i)) {
        _ctrls.remove(i)?.dispose();
      }
    }
    for (final i in keep) {
      if (!_ctrls.containsKey(i) && !_failed.contains(i)) _start(i);
    }
  }

  Future<void> _start(int i) async {
    final api = apiOf(context);
    final s = _items[i];
    final c = LensVideo(api.stream(s.id), headers: api.headers, bufferMb: 12);
    _ctrls[i] = c;
    try {
      await c.initialize();
      if (!mounted || _ctrls[i] != c) {
        if (_ctrls[i] != c) c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(context.read<AppState>().feedMuted ? 0 : 1);
      // start somewhere in the middle, deterministic per scene, so it isn't always the intro
      final d = c.value.duration.inMilliseconds;
      if (d > 60000) {
        final f = 0.1 + ((s.id * 2654435761) % 1000) / 1000 * 0.6;
        await c.seekTo(Duration(milliseconds: (d * f).round()));
      }
      if (i == _cur && _shouldPlay) await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (_ctrls[i] == c) _ctrls.remove(i);
      c.dispose();
      _failed.add(i);
      if (mounted) setState(() {});
    }
  }

  void _onPage(int i) {
    final old = _ctrls[_cur];
    old?.pause();
    _cur = i;
    _windowControllers();
    final c = _ctrls[i];
    if (c != null && c.value.isInitialized && _shouldPlay) c.play();
    if (i >= _items.length - 4) _more();
    setState(() {});
  }

  Future<void> _open(Future<void> Function() go) async {
    _away = true;
    _sync();
    await go();
    _away = false;
    _sync();
  }

  void _toggleMute() {
    final st = context.read<AppState>();
    st.setFeedMuted(!st.feedMuted);
    for (final c in _ctrls.values) {
      if (c.value.isInitialized) c.setVolume(st.feedMuted ? 0 : 1);
    }
  }

  void _tap() {
    final c = _ctrls[_cur];
    if (c == null || !c.value.isInitialized) return;
    _paused = !_paused;
    _sync();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.select<AppState, bool>((s) => s.feedMuted);
    final top = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(child: _body(muted)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(top: top + 6, bottom: 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC000000), Color(0x00000000)]),
            ),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _modes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final on = i == _mode;
                  return GestureDetector(
                    onTap: () => _setMode(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: on ? Colors.white : const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(_modes[i].label,
                          style: TextStyle(color: on ? Colors.black : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body(bool muted) {
    if (_items.isEmpty) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: Pal.mute),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Pal.mute)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _more, child: const Text('Try again')),
            ]),
          ),
        );
      }
      if (_loading || _pageNo == 0) return const Center(child: CircularProgressIndicator(color: Pal.a));
      return const Center(child: Text('Nothing here yet.', style: TextStyle(color: Pal.mute)));
    }
    return PageView.builder(
      controller: _pc,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPage,
      itemCount: _items.length,
      itemBuilder: (_, i) => _FeedPage(
        key: ValueKey(_items[i].id),
        scene: _items[i],
        ctrl: _ctrls[i],
        failed: _failed.contains(i),
        isCurrent: i == _cur,
        paused: _paused,
        muted: muted,
        onTap: _tap,
        onMute: _toggleMute,
        onOpen: () => _open(() => openScene(context, _items[i])),
        onPerformer: (id) => _open(() => openPerformer(context, id)),
      ),
    );
  }
}

class _FeedPage extends StatefulWidget {
  const _FeedPage({
    super.key,
    required this.scene,
    required this.ctrl,
    required this.failed,
    required this.isCurrent,
    required this.paused,
    required this.muted,
    required this.onTap,
    required this.onMute,
    required this.onOpen,
    required this.onPerformer,
  });
  final Scene scene;
  final LensVideo? ctrl;
  final bool failed;
  final bool isCurrent;
  final bool paused;
  final bool muted;
  final VoidCallback onTap;
  final VoidCallback onMute;
  final VoidCallback onOpen;
  final void Function(int) onPerformer;
  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  bool _fill = false;
  bool _dragging = false;
  double _dragV = 0;
  LensVideo? _listening;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(_FeedPage old) {
    super.didUpdateWidget(old);
    if (old.ctrl != widget.ctrl) _attach();
  }

  void _attach() {
    _listening?.removeListener(_tick);
    _listening = widget.ctrl;
    _listening?.addListener(_tick);
  }

  void _tick() {
    if (mounted && widget.isCurrent) setState(() {});
  }

  @override
  void dispose() {
    _listening?.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final s = widget.scene;
    final c = widget.ctrl;
    final ready = c != null && c.value.isInitialized;
    final bottom = MediaQuery.of(context).padding.bottom;
    final navPad = bottom + 80; // room for the bottom navigation bar
    final names = s.performers.map((p) => p.name).join(', ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: () => setState(() => _fill = !_fill),
      child: Stack(fit: StackFit.expand, children: [
        // blurred backdrop so letterboxing looks intentional
        LImage(api.img('scene', s.id, w: 480)),
        Container(color: const Color(0xAA000000)),
        if (ready)
          Center(
            child: FittedBox(
              fit: _fill ? BoxFit.cover : BoxFit.contain,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: LensVideoView(c)),
            ),
          )
        else
          Center(child: LImage(api.img('scene', s.id, w: 720), fit: BoxFit.contain)),
        if (!ready && !widget.failed) const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5)),
        if (widget.failed)
          Align(
            alignment: const Alignment(0, -0.5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(12)),
              child: const Text("Can't play this file on this phone", style: TextStyle(color: Colors.white70)),
            ),
          ),
        if (widget.isCurrent && widget.paused && ready)
          const Center(child: Icon(Icons.play_arrow_rounded, size: 84, color: Colors.white70)),
        // bottom shade
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 340,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xE6000000), Color(0x00000000)]),
              ),
            ),
          ),
        ),
        // caption
        Positioned(
          left: 16,
          right: 84,
          bottom: navPad + 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (names.isNotEmpty)
              Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if ((s.studio ?? '').isNotEmpty) Text(s.studio!, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
              if (s.res != null) ResBadge(s.res!),
              for (final t in s.tags.take(3)) Text('#${t.name.replaceAll(' ', '')}', style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
            ]),
          ]),
        ),
        // action rail
        Positioned(
          right: 10,
          bottom: navPad + 22,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (s.performers.isNotEmpty) ...[
              GestureDetector(
                onTap: () => widget.onPerformer(s.performers.first.id),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: Avatar(s.performers.first.id, size: 46),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (s.rating != null) ...[
              const Icon(Icons.star_rounded, color: Pal.gold, size: 32),
              Text((s.rating! / 20).toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
            ],
            if (s.oCount > 0) ...[
              const Icon(Icons.favorite_rounded, color: Pal.a, size: 30),
              Text('${s.oCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
            ],
            _RailBtn(icon: widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, label: widget.muted ? 'Muted' : 'Sound', onTap: widget.onMute),
            const SizedBox(height: 14),
            _RailBtn(
              icon: _fill ? Icons.fit_screen_rounded : Icons.crop_free_rounded,
              label: _fill ? 'Fill' : 'Fit',
              onTap: () => setState(() => _fill = !_fill),
            ),
            const SizedBox(height: 14),
            _RailBtn(icon: Icons.info_outline_rounded, label: 'Open', onTap: widget.onOpen),
          ]),
        ),
        // progress bar
        if (ready && widget.isCurrent) Positioned(left: 0, right: 0, bottom: navPad - 6, child: _bar(c)),
      ]),
    );
  }

  Widget _bar(LensVideo c) {
    final total = c.value.duration.inMilliseconds;
    final pos = _dragging ? _dragV : c.value.position.inMilliseconds.toDouble();
    final f = total == 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, box) {
      void seek(double dx) {
        _dragV = (dx / box.maxWidth).clamp(0.0, 1.0) * total;
      }

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (d) => setState(() {
          _dragging = true;
          seek(d.localPosition.dx);
        }),
        onHorizontalDragUpdate: (d) => setState(() => seek(d.localPosition.dx)),
        onHorizontalDragEnd: (_) {
          c.seekTo(Duration(milliseconds: _dragV.round()));
          setState(() => _dragging = false);
        },
        onTapUp: (d) {
          seek(d.localPosition.dx);
          c.seekTo(Duration(milliseconds: _dragV.round()));
        },
        child: SizedBox(
          height: 28,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_dragging)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${fmtTime(pos / 1000)} / ${fmtTime(total / 1000)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            Container(
              height: _dragging ? 5 : 2.5,
              alignment: Alignment.centerLeft,
              color: const Color(0x44FFFFFF),
              child: FractionallySizedBox(widthFactor: f, child: Container(color: Pal.a)),
            ),
          ]),
        ),
      );
    });
  }
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
