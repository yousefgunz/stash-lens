import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
            child: Row(children: [
              Expanded(child: Text('Browse', style: heading(34))),
              IconButton(onPressed: () => openSearch(context), icon: const Icon(Icons.search_rounded)),
            ]),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(borderSide: BorderSide(width: 3, color: Pal.a), borderRadius: BorderRadius.all(Radius.circular(3))),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
            unselectedLabelColor: Pal.mute,
            tabs: const [Tab(text: 'Studios'), Tab(text: 'Tags')],
          ),
          const Expanded(child: TabBarView(children: [_Studios(), _Tags()])),
        ]),
      ),
    );
  }
}

const _stSorts = <(String, String, String)>[
  ('Most scenes', 'scenes', 'desc'),
  ('Name', 'name', 'asc'),
  ('Fan favourites', 'o_count', 'desc'),
  ('Rating', 'rating', 'desc'),
  ('Recently added', 'last', 'desc'),
  ('Longest', 'duration', 'desc'),
];

class _Studios extends StatefulWidget {
  const _Studios();
  @override
  State<_Studios> createState() => _StudiosState();
}

class _StudiosState extends State<_Studios> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _scroll = ScrollController();
  final _items = <Studio>[];
  int _page = 0, _pages = 1, _rq = 0, _sort = 0;
  bool _loading = false, _done = false, _fav = false;
  String? _error;
  String _q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 700) _load();
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
      final s = _stSorts[_sort];
      final d = await apiOf(context).studios({'q': _q, 'sort': s.$2, 'dir': s.$3, 'favorite': _fav ? 1 : null, 'per': 40, 'page': _page + 1});
      if (!mounted || rq != _rq) return;
      setState(() {
        _page++;
        _pages = d.pages;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottom = MediaQuery.of(context).padding.bottom + 90;
    return CustomScrollView(controller: _scroll, slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                decoration: const InputDecoration(hintText: 'Search studios', prefixIcon: Icon(Icons.search_rounded, color: Pal.dim), isDense: true),
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
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _stSorts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => LChip(_stSorts[i].$1, selected: _sort == i, onTap: () {
              _sort = i;
              _reset();
            }),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      if (_error != null && _items.isEmpty)
        SliverToBoxAdapter(child: ErrorNote(_error!, onRetry: _reset))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.7),
            delegate: SliverChildBuilderDelegate((_, i) => StudioTile(_items[i]), childCount: _items.length),
          ),
        ),
      SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, bottom), child: Center(child: _loading ? const Spin() : const SizedBox.shrink()))),
    ]);
  }
}

class _Tags extends StatefulWidget {
  const _Tags();
  @override
  State<_Tags> createState() => _TagsState();
}

class _TagsState extends State<_Tags> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _scroll = ScrollController();
  final _items = <TagItem>[];
  int _page = 0, _pages = 1, _rq = 0, _sort = 0, _max = 1;
  bool _loading = false, _done = false, _fav = false;
  String? _error;
  String _q = '';
  Timer? _debounce;

  static const _sorts = <(String, String, String)>[('Most scenes', 'scenes', 'desc'), ('Name', 'name', 'asc'), ('Most performers', 'performers', 'desc')];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 700) _load();
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
      final s = _sorts[_sort];
      final d = await apiOf(context).tags({'q': _q, 'sort': s.$2, 'dir': s.$3, 'favorite': _fav ? 1 : null, 'used': 1, 'per': 120, 'page': _page + 1});
      if (!mounted || rq != _rq) return;
      setState(() {
        _page++;
        _pages = d.pages;
        _max = d.extra['max_scenes'] as int;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottom = MediaQuery.of(context).padding.bottom + 90;
    return CustomScrollView(controller: _scroll, slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                decoration: const InputDecoration(hintText: 'Search tags', prefixIcon: Icon(Icons.search_rounded, color: Pal.dim), isDense: true),
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
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _sorts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => LChip(_sorts[i].$1, selected: _sort == i, onTap: () {
              _sort = i;
              _reset();
            }),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
      if (_error != null && _items.isEmpty)
        SliverToBoxAdapter(child: ErrorNote(_error!, onRetry: _reset))
      else
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 9, runSpacing: 9, children: [for (final t in _items) TagTile(t, _max)]),
          ),
        ),
      SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, bottom), child: Center(child: _loading ? const Spin() : const SizedBox.shrink()))),
    ]);
  }
}
