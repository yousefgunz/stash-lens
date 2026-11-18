import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

const kSorts = <(String, String, String)>[
  // label, key, default direction
  ('Recently added', 'created', 'desc'),
  ('Release date', 'date', 'desc'),
  ('Rating', 'rating', 'desc'),
  ('Most played', 'plays', 'desc'),
  ('Fan favourites', 'o_count', 'desc'),
  ('Longest', 'duration', 'desc'),
  ('Largest', 'size', 'desc'),
  ('Title A–Z', 'title', 'asc'),
  ('Recently watched', 'last_played', 'desc'),
  ('Shuffle', 'random', 'desc'),
];

const kRes = ['', '8K', '6K', '4K', '1440p', '1080p', '720p', '480p', 'SD'];

const kFlags = <(String, String)>[
  ('', 'Everything'),
  ('unplayed', 'Unwatched'),
  ('resumable', 'In progress'),
  ('favorites', 'From favourites'),
  ('unrated', 'Unrated'),
  ('no_performers', 'No performers'),
  ('no_studio', 'No studio'),
  ('no_tags', 'No tags'),
  ('unorganized', 'Not organized'),
  ('low_res', 'Low resolution'),
  ('short', 'Under 1 min'),
  ('no_stashid', 'Not linked to stash-box'),
];

/// Searchable, sortable, filterable, infinitely-scrolling scene grid. Reused by the Scenes tab, studios, tags, performers, health…
class SceneBrowser extends StatefulWidget {
  const SceneBrowser({super.key, this.title, this.fixed = const {}, this.initialSort, this.header, this.showBack = false});
  final String? title;
  final Map<String, dynamic> fixed;
  final String? initialSort;
  final Widget? header;
  final bool showBack;

  @override
  State<SceneBrowser> createState() => _SceneBrowserState();
}

class _SceneBrowserState extends State<SceneBrowser> {
  final _scroll = ScrollController();
  final _items = <Scene>[];
  int _page = 0, _pages = 1, _total = 0, _rq = 0;
  bool _loading = false, _done = false;
  String? _error;

  late String _q;
  late int _sort;
  late String _dir;
  late String _res;
  late String _flag;
  int _ratingMin = 0;
  String _organized = '';
  String _year = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _q = (widget.fixed['q'] ?? '').toString();
    final i = kSorts.indexWhere((s) => s.$2 == widget.initialSort);
    _sort = i < 0 ? 0 : i;
    _dir = kSorts[_sort].$3;
    _res = (widget.fixed['res'] ?? '').toString();
    _flag = (widget.fixed['flag'] ?? '').toString();
    _year = (widget.fixed['year'] ?? '').toString();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 900) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _query => {
        ...widget.fixed,
        'q': _q,
        'sort': kSorts[_sort].$2,
        'dir': _dir,
        'res': _res,
        'flag': _flag,
        'year': _year,
        'rating_min': _ratingMin > 0 ? _ratingMin : null,
        'organized': _organized,
        'per': 36,
      };

  int get _activeFilters => [_res, _flag, _year, _organized].where((e) => e.isNotEmpty).length + (_ratingMin > 0 ? 1 : 0);

  Future<void> _reset() async {
    _rq++;
    setState(() {
      _items.clear();
      _page = 0;
      _pages = 1;
      _done = false;
      _error = null;
      _loading = false;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    final rq = _rq;
    setState(() => _loading = true);
    try {
      final d = await apiOf(context).scenes({..._query, 'page': _page + 1});
      if (!mounted || rq != _rq) return;
      setState(() {
        _page++;
        _pages = d.pages;
        _total = d.total;
        _items.addAll(d.items);
        _done = _page >= _pages || d.items.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (mounted && rq == _rq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        void apply(VoidCallback f) {
          f();
          set(() {});
          setState(() {});
        }

        Widget group(String t, List<Widget> chips) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(color: Pal.mute, fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ]),
            );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.95,
          builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Row(children: [
              Text('Filters', style: heading(24)),
              const Spacer(),
              TextButton(
                onPressed: () => apply(() {
                  _res = '';
                  _flag = '';
                  _year = '';
                  _organized = '';
                  _ratingMin = 0;
                }),
                child: const Text('Reset', style: TextStyle(color: Pal.a)),
              ),
            ]),
            const SizedBox(height: 10),
            group('Resolution', [for (final r in kRes) LChip(r.isEmpty ? 'Any' : r, selected: _res == r, onTap: () => apply(() => _res = r))]),
            group('Show', [for (final f in kFlags) LChip(f.$2, selected: _flag == f.$1, onTap: () => apply(() => _flag = f.$1))]),
            group('Minimum rating', [
              for (var i = 0; i <= 5; i++) LChip(i == 0 ? 'Any' : '$i★', selected: _ratingMin == i, onTap: () => apply(() => _ratingMin = i)),
            ]),
            group('Organized', [
              for (final o in const [('', 'Any'), ('1', 'Organized'), ('0', 'Not organized')])
                LChip(o.$2, selected: _organized == o.$1, onTap: () => apply(() => _organized = o.$1)),
            ]),
            group('Release year', [
              LChip('Any', selected: _year.isEmpty, onTap: () => apply(() => _year = '')),
              for (var y = DateTime.now().year; y > DateTime.now().year - 14; y--)
                LChip('$y', selected: _year == '$y', onTap: () => apply(() => _year = '$y')),
            ]),
            const SizedBox(height: 4),
            GradButton(
              label: 'Show results',
              expand: true,
              onTap: () {
                Navigator.pop(ctx);
                _reset();
              },
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 90;
    return RefreshIndicator(
      color: Pal.a,
      backgroundColor: Pal.bg3,
      onRefresh: () async {
        apiOf(context).clearCache();
        await _reset();
      },
      child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        if (widget.title != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(widget.showBack ? 6 : 20, 14, 8, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                if (widget.showBack) IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(child: Text(widget.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: heading(34))),
                if (_total > 0) Padding(padding: const EdgeInsets.only(right: 4), child: Text(fmtNum(_total), style: const TextStyle(color: Pal.mute, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => openSearch(context), icon: const Icon(Icons.search_rounded)),
              ]),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 450), () {
                      _q = v;
                      _reset();
                    });
                  },
                  decoration: const InputDecoration(hintText: 'Filter by title, performer, studio, tag…', prefixIcon: Icon(Icons.search_rounded, color: Pal.dim), isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Badge(
                isLabelVisible: _activeFilters > 0,
                label: Text('$_activeFilters'),
                backgroundColor: Pal.a,
                child: IconButton.filled(
                  onPressed: _openFilters,
                  style: IconButton.styleFrom(backgroundColor: Pal.bg3, foregroundColor: Pal.ink),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: kSorts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return LChip(_dir == 'desc' ? 'High → low' : 'Low → high', icon: _dir == 'desc' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, onTap: () {
                    _dir = _dir == 'desc' ? 'asc' : 'desc';
                    _reset();
                  });
                }
                final k = i - 1;
                return LChip(kSorts[k].$1, selected: _sort == k, onTap: () {
                  _sort = k;
                  _dir = kSorts[k].$3;
                  _reset();
                });
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        if (_error != null && _items.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 40), child: ErrorNote(_error!, onRetry: _reset)))
        else
          SliverLayoutBuilder(builder: (context, c) {
            final w = c.crossAxisExtent - 40;
            const gap = 14.0;
            final cols = w < 560 ? 2 : (w / 300).floor().clamp(2, 6);
            final cardW = (w - gap * (cols - 1)) / cols;
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: 18,
                  mainAxisExtent: cardW * 9 / 16 + 100,
                ),
                delegate: SliverChildBuilderDelegate((_, i) => SceneCard(_items[i], index: i % 6), childCount: _items.length),
              ),
            );
          }),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottom),
            child: Center(
              child: _loading
                  ? const Spin()
                  : (_items.isEmpty && _error == null && _page > 0)
                      ? const Text('Nothing matches these filters.', style: TextStyle(color: Pal.mute))
                      : (_error != null ? Text(_error!, style: const TextStyle(color: Pal.a)) : const SizedBox.shrink()),
            ),
          ),
        ),
      ]),
    );
  }
}
