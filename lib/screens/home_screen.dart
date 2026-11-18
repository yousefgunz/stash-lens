import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _gen = 0;

  Future<void> _refresh() async {
    apiOf(context).clearCache();
    setState(() => _gen++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Rail _scenes(String title, {String sort = 'created', Map<String, dynamic> filters = const {}, int per = 14, bool ranked = false, bool seeAll = true}) {
    final api = apiOf(context);
    return Rail(
      key: ValueKey('$title$_gen'),
      title: title,
      onMore: seeAll ? () => openScenes(context, title: title, filters: filters, sort: sort) : null,
      load: () async {
        final d = await api.scenes({...filters, 'sort': sort, 'per': per});
        return [
          for (var i = 0; i < d.items.length; i++)
            SizedBox(width: 272, child: SceneCard(d.items[i], index: i, rank: ranked ? i + 1 : null)),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final now = DateTime.now();
    final md = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final bottomPad = MediaQuery.of(context).padding.bottom + 90;

    return RefreshIndicator(
      color: Pal.a,
      backgroundColor: Pal.bg3,
      edgeOffset: 80,
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomPad),
        children: [
          HomeHero(key: ValueKey('hero$_gen')),
          const SizedBox(height: 22),
          Rail(
            key: ValueKey('cw$_gen'),
            title: 'Continue watching',
            onMore: () => openScenes(context, title: 'In progress', filters: {'flag': 'resumable'}, sort: 'last_played'),
            load: () async {
              final local = context.read<AppState>().progList().take(20).toList();
              final results = await Future.wait([
                api.scenes({'flag': 'resumable', 'sort': 'last_played', 'per': 20}),
                local.isEmpty ? Future.value(Paged<Scene>([], 0, 0)) : api.scenes({'ids': local.map((e) => e.id).join(','), 'per': 40}),
              ]);
              final byId = {for (final s in results[1].items) s.id: s};
              final out = <Scene>[];
              final seen = <int>{};
              for (final l in local) {
                final s = byId[l.id];
                if (s != null) {
                  out.add(s);
                  seen.add(s.id);
                }
              }
              for (final s in results[0].items) {
                if (seen.add(s.id)) out.add(s);
              }
              return [for (var i = 0; i < out.length && i < 20; i++) SizedBox(width: 272, child: SceneCard(out[i], index: i))];
            },
          ),
          Spotlight(key: ValueKey('spot$_gen')),
          Rail(
            key: ValueKey('otd$_gen'),
            title: 'On this day',
            load: () async {
              final l = await api.onThisDay(md, now.year);
              return [for (var i = 0; i < l.length; i++) SizedBox(width: 272, child: SceneCard(l[i], index: i))];
            },
          ),
          Rail(
            key: ValueKey('bd$_gen'),
            title: 'Birthdays today',
            height: 224,
            load: () async {
              final l = await api.birthdays(md, now.year);
              return [for (var i = 0; i < l.length; i++) SizedBox(width: 128, child: PerformerCard(l[i], index: i))];
            },
          ),
          _scenes('New from your favourites', filters: {'flag': 'favorites'}),
          _scenes('Recently added'),
          _scenes('Top 10 · most played', sort: 'plays', per: 10, ranked: true),
          _scenes('Highest rated', sort: 'rating'),
          Rail(
            key: ValueKey('pw$_gen'),
            title: 'Performers you watch most',
            height: 224,
            load: () async {
              final d = await api.performers({'sort': 'scenes', 'dir': 'desc', 'per': 24});
              return [for (var i = 0; i < d.items.length; i++) SizedBox(width: 128, child: PerformerCard(d.items[i], index: i))];
            },
          ),
          _scenes('8K showcase', filters: {'res': '8K'}),
          _scenes('6K', filters: {'res': '6K'}),
          _scenes('Ultra HD · 4K', filters: {'res': '4K'}),
          Rail(
            key: ValueKey('st$_gen'),
            title: 'Browse by studio',
            height: 104,
            load: () async {
              final d = await api.studios({'sort': 'scenes', 'per': 24});
              return [for (final s in d.items) SizedBox(width: 178, child: StudioTile(s))];
            },
          ),
          _scenes('Fan favourites', sort: 'o_count'),
          Rail(
            key: ValueKey('tg$_gen'),
            title: 'Browse by tag',
            height: 46,
            load: () async {
              final d = await api.tags({'sort': 'scenes', 'per': 30});
              final mx = d.extra['max_scenes'] as int;
              return [for (final t in d.items) Center(child: TagTile(t, mx))];
            },
          ),
          _scenes('Still unwatched', sort: 'random', filters: {'flag': 'unplayed'}),
          _scenes('Feature length', sort: 'duration'),
          _scenes('Shuffle · something different', sort: 'random', seeAll: false),
          const StatsBand(),
        ],
      ),
    );
  }
}

// ───────────────────────────── hero ─────────────────────────────

class HomeHero extends StatefulWidget {
  const HomeHero({super.key});
  @override
  State<HomeHero> createState() => _HeroState();
}

class _HeroState extends State<HomeHero> {
  final _ctl = PageController();
  Timer? _timer;
  int _i = 0;
  List<Scene> _items = [];
  Map<String, String> _desc = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = apiOf(context);
    try {
      // Same rules as the web app: scenes with a custom hero image first, then the highest rated scenes up to 6 slides.
      final h = await api.get('hero-ids') as Map<String, dynamic>?;
      final field = (h?['field'] ?? '').toString();
      var items = <Scene>[];
      if (field.isNotEmpty) {
        items = (await api.scenes({'flag': 'has_hero', 'sort': 'random', 'per': 8}, )).items.take(6).toList();
      } else {
        final ids = ((h?['ids'] as List?) ?? const []).map((e) => (e as num).toInt()).take(200).toList();
        if (ids.isNotEmpty) {
          items = (await api.scenes({'ids': ids.join(','), 'per': 200})).items.toList()..shuffle();
        }
        if (items.length < 6) {
          final top = (await api.scenes({'sort': 'rating', 'per': 40})).items.where((x) => !items.any((o) => o.id == x.id)).toList()..shuffle();
          items = [...items, ...top.take(6 - items.length)];
        }
      }
      final desc = await api.details(items.map((e) => e.id).toList());
      if (!mounted) return;
      setState(() {
        _items = items;
        _desc = desc;
        _loading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (!mounted || _items.length < 2 || !_ctl.hasClients) return;
        _ctl.animateToPage((_i + 1) % _items.length, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final h = (MediaQuery.of(context).size.height * 0.62).clamp(420.0, 620.0);
    return SizedBox(
      height: h,
      child: Stack(children: [
        if (_loading) const Spin(),
        if (_error != null) Positioned.fill(child: ErrorNote(_error!, onRetry: () => setState(() {
          _loading = true;
          _error = null;
          _load();
        }))),
        if (_items.isNotEmpty)
          PageView.builder(
            controller: _ctl,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => _HeroSlide(_items[i], _desc['${_items[i].id}'], active: i == _i),
          ),
        // top bar
        Positioned(
          left: 20,
          right: 12,
          top: top + 10,
          child: Row(children: [
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Row(children: [Text('Stash', style: heading(25)), GradText('Lens', heading(25))]),
            const Spacer(),
            IconButton(
              onPressed: () => openSearch(context),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
              icon: const Icon(Icons.search_rounded),
            ),
          ]),
        ),
        if (_items.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: i == _i ? Pal.grad : null,
                    color: i == _i ? null : Colors.white30,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide(this.s, this.desc, {required this.active});
  final Scene s;
  final String? desc;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final eyebrow = [if (s.studio != null) s.studio!, if (s.year != null) s.year!].join('  ·  ');
    return Stack(fit: StackFit.expand, children: [
      LImage(s.hero ? api.hero(s.id) : api.img('scene', s.id, w: 1280), alignment: Alignment.topCenter),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0x99000000), Colors.transparent, Color(0x9907080C), Pal.bg], stops: [0, 0.3, 0.7, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 36,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (eyebrow.isNotEmpty) Text(eyebrow.toUpperCase(), style: const TextStyle(color: Pal.a2, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: heading(36)),
          const SizedBox(height: 10),
          Row(children: [
            ResBadge(s.res),
            if (s.res != null) const SizedBox(width: 8),
            Text(fmtTime(s.duration), style: const TextStyle(color: Pal.mute, fontWeight: FontWeight.w600)),
            if (s.stars > 0) ...[const SizedBox(width: 10), Stars(s.stars, size: 14)],
            if (s.performers.isNotEmpty) ...[
              const SizedBox(width: 10),
              Flexible(child: Text(s.performers.take(2).map((p) => p.name).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.mute))),
            ],
          ]),
          if (desc != null) ...[
            const SizedBox(height: 8),
            Text(desc!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.mute, height: 1.35, fontSize: 13.5)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            GradButton(label: 'Play', icon: Icons.play_arrow_rounded, onTap: () => playScene(context, s)),
            const SizedBox(width: 10),
            GhostButton(label: 'Details', icon: Icons.info_outline_rounded, onTap: () => openScene(context, s)),
          ]),
        ]).animate(key: ValueKey(active), target: active ? 1 : 0).fadeIn(duration: 500.ms).slideY(begin: 0.04, end: 0),
      ),
    ]);
  }
}

// ───────────────────────────── performer spotlight ─────────────────────────────

class Spotlight extends StatefulWidget {
  const Spotlight({super.key});
  @override
  State<Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<Spotlight> {
  late final Future<Map<String, dynamic>?> _f = apiOf(context).spotlight();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _f,
      builder: (context, snap) {
        final d = snap.data;
        final item = d?['item'] as Map<String, dynamic>?;
        if (item == null) return const SizedBox.shrink();
        final api = apiOf(context);
        final id = (item['id'] as num).toInt();
        final scenes = ((d!['scenes'] as List?) ?? const []).map((e) => Scene.fromJson(e as Map<String, dynamic>)).toList();
        final tags = ((item['top_tags'] as List?) ?? const []).take(5).map((e) => (e as Map)['name'].toString()).toList();
        final bits = <String>[
          if (item['age'] != null) '${item['age']}',
          if (item['country'] != null) '${item['country']}',
          '${item['scenes']} scenes',
          if ((item['total_duration'] as num?) != null) fmtHours((item['total_duration'] as num).toDouble()),
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Pal.bg2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Pal.line),
              gradient: LinearGradient(colors: [const Color(0xFF2A1219), Pal.bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => openPerformer(context, id),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(width: 92, height: 120, child: LImage(api.img('performer', id, w: 400), alignment: Alignment.topCenter, icon: Icons.person_rounded)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PERFORMER OF THE DAY', style: TextStyle(color: Pal.a2, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.3)),
                      const SizedBox(height: 6),
                      Text(item['name'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: heading(26)),
                      const SizedBox(height: 6),
                      Text(bits.join('  ·  '), style: const TextStyle(color: Pal.mute, fontSize: 13)),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags.take(3)) LChip(t)]),
                      ],
                    ]),
                  ),
                ]),
              ),
              if (scenes.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: scenes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(width: 200, child: SceneCard(scenes[i], index: 99)),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ───────────────────────────── stats band ─────────────────────────────

class StatsBand extends StatefulWidget {
  const StatsBand({super.key});
  @override
  State<StatsBand> createState() => _StatsBandState();
}

class _StatsBandState extends State<StatsBand> {
  late final Future<Map<String, dynamic>> _f = apiOf(context).overview();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (context, snap) {
        final ov = snap.data;
        if (ov == null) return const SizedBox.shrink();
        final total = (ov['scene_total'] as num?) ?? 0;
        final hours = ((ov['duration'] as num?) ?? 0) / 3600;
        final tb = ((ov['size'] as num?) ?? 0) / 1099511627776;
        final res = ((ov['resolutions'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final rt = res.fold<num>(0, (a, b) => a + (b['n'] as num));
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(18), border: Border.all(color: Pal.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _Stat(fmtNum(total), 'Scenes'),
                _Stat(fmtNum(hours), 'Hours'),
                _Stat('${tb.toStringAsFixed(1)} TB', 'On disk'),
                _Stat(fmtNum((ov['plays_total'] as num?) ?? 0), 'Plays'),
              ]),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 9,
                  child: Row(children: [
                    for (final r in res)
                      Expanded(flex: ((r['n'] as num).toInt()).clamp(1, 1 << 30), child: Container(color: Pal.resColors[r['label']] ?? Pal.dim)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 4, children: [
                for (final r in res)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Pal.resColors[r['label']] ?? Pal.dim, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('${r['label']} ${(100 * (r['n'] as num) / (rt == 0 ? 1 : rt)).round()}%', style: const TextStyle(color: Pal.mute, fontSize: 11.5)),
                  ]),
              ]),
              const SizedBox(height: 12),
              Text('${fmtNum(((ov['counts'] as Map?)?['markers'] as num?) ?? 0)} markers  ·  read-only view of your Stash library', style: const TextStyle(color: Pal.dim, fontSize: 12)),
            ]),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.v, this.label);
  final String v;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: GradText(v, heading(23))),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Pal.mute, fontSize: 12)),
        ]),
      );
}
