import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

const _pSorts = <(String, String, String)>[
  ('Name', 'name', 'asc'),
  ('Most scenes', 'scenes', 'desc'),
  ('Fan favourites', 'o_count', 'desc'),
  ('Rating', 'rating', 'desc'),
  ('Recently added', 'created', 'desc'),
  ('Youngest', 'birthdate', 'desc'),
  ('Oldest', 'birthdate', 'asc'),
  ('Tallest', 'height', 'desc'),
  ('Shuffle', 'random', 'asc'),
];

class PerformersScreen extends StatefulWidget {
  const PerformersScreen({super.key});
  @override
  State<PerformersScreen> createState() => _PerformersScreenState();
}

class _PerformersScreenState extends State<PerformersScreen> {
  final _scroll = ScrollController();
  final _items = <Performer>[];
  int _page = 0, _pages = 1, _total = 0, _rq = 0;
  bool _loading = false, _done = false, _fav = false;
  String? _error;
  String _q = '';
  String _gender = '';
  String _country = '';
  int _sort = 1;
  int _minScenes = 0;
  List<String> _genders = [], _countries = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
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

  Future<void> _reset() async {
    _rq++;
    setState(() {
      _items.clear();
      _page = 0;
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
      final s = _pSorts[_sort];
      final d = await apiOf(context).performers({
        'q': _q,
        'sort': s.$2,
        'dir': s.$3,
        'gender': _gender,
        'country': _country,
        'favorite': _fav ? 1 : null,
        'min_scenes': _minScenes > 0 ? _minScenes : null,
        'per': 45,
        'page': _page + 1,
      });
      if (!mounted || rq != _rq) return;
      setState(() {
        _page++;
        _pages = d.pages;
        _total = d.total;
        _items.addAll(d.items);
        _done = _page >= _pages || d.items.isEmpty;
        _loading = false;
        _genders = ((d.facets['genders'] as List?) ?? const []).map((e) => e.toString()).toList();
        _countries = ((d.facets['countries'] as List?) ?? const []).map((e) => e.toString()).toList();
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

  void _filters() {
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

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Row(children: [
              Text('Filters', style: heading(24)),
              const Spacer(),
              TextButton(
                onPressed: () => apply(() {
                  _gender = '';
                  _country = '';
                  _minScenes = 0;
                  _fav = false;
                }),
                child: const Text('Reset', style: TextStyle(color: Pal.a)),
              ),
            ]),
            const SizedBox(height: 10),
            const Text('Gender', style: TextStyle(color: Pal.mute, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              LChip('Any', selected: _gender.isEmpty, onTap: () => apply(() => _gender = '')),
              for (final g in _genders) LChip(g[0] + g.substring(1).toLowerCase().replaceAll('_', ' '), selected: _gender == g, onTap: () => apply(() => _gender = g)),
            ]),
            const SizedBox(height: 18),
            const Text('Country', style: TextStyle(color: Pal.mute, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              LChip('Any', selected: _country.isEmpty, onTap: () => apply(() => _country = '')),
              for (final c in _countries) LChip(c, selected: _country == c, onTap: () => apply(() => _country = c)),
            ]),
            const SizedBox(height: 18),
            const Text('Minimum scenes', style: TextStyle(color: Pal.mute, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final n in const [0, 2, 5, 10, 20]) LChip(n == 0 ? 'Any' : '$n+', selected: _minScenes == n, onTap: () => apply(() => _minScenes = n)),
            ]),
            const SizedBox(height: 24),
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
    final active = (_gender.isNotEmpty ? 1 : 0) + (_country.isNotEmpty ? 1 : 0) + (_minScenes > 0 ? 1 : 0);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Pal.a,
        backgroundColor: Pal.bg3,
        onRefresh: () async {
          apiOf(context).clearCache();
          await _reset();
        },
        child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(children: [
                Expanded(child: Text('Performers', style: heading(34))),
                if (_total > 0) Text(fmtNum(_total), style: const TextStyle(color: Pal.mute, fontWeight: FontWeight.w800)),
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
                    decoration: const InputDecoration(hintText: 'Search name or alias', prefixIcon: Icon(Icons.search_rounded, color: Pal.dim), isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: () {
                    _fav = !_fav;
                    _reset();
                  },
                  style: IconButton.styleFrom(backgroundColor: _fav ? Pal.a : Pal.bg3, foregroundColor: _fav ? Colors.white : Pal.mute),
                  icon: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                ),
                const SizedBox(width: 6),
                Badge(
                  isLabelVisible: active > 0,
                  label: Text('$active'),
                  backgroundColor: Pal.a,
                  child: IconButton.filled(onPressed: _filters, style: IconButton.styleFrom(backgroundColor: Pal.bg3, foregroundColor: Pal.ink), icon: const Icon(Icons.tune_rounded)),
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
                itemCount: _pSorts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => LChip(_pSorts[i].$1, selected: _sort == i, onTap: () {
                  _sort = i;
                  _reset();
                }),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          if (_error != null && _items.isEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 40), child: ErrorNote(_error!, onRetry: _reset)))
          else
            SliverLayoutBuilder(builder: (context, c) {
              final w = c.crossAxisExtent - 40;
              const gap = 12.0;
              final cols = w < 560 ? 3 : (w / 160).floor().clamp(3, 8);
              final cardW = (w - gap * (cols - 1)) / cols;
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: gap, mainAxisSpacing: 16, mainAxisExtent: cardW * 4 / 3 + 50),
                  delegate: SliverChildBuilderDelegate((_, i) => PerformerCard(_items[i], index: i % 9), childCount: _items.length),
                ),
              );
            }),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, bottom),
              child: Center(child: _loading ? const Spin() : (_items.isEmpty && _error == null && _page > 0 ? const Text('No performers match.', style: TextStyle(color: Pal.mute)) : const SizedBox.shrink())),
            ),
          ),
        ]),
      ),
    );
  }
}
