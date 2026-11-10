import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

const _sorts = <(String, String, String)>[
  ('Recently added', 'created_at', 'DESC'),
  ('Release date', 'date', 'DESC'),
  ('Highest rated', 'rating', 'DESC'),
  ('Last played', 'last_played_at', 'DESC'),
  ('Title A–Z', 'title', 'ASC'),
  ('Longest', 'duration', 'DESC'),
  ('Random', 'random', 'DESC'),
];

class ScenesScreen extends StatelessWidget {
  const ScenesScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(child: SceneBrowser(title: 'Scenes'));
}

/// Searchable, sortable, infinitely-scrolling scene grid. Reused for performer pages.
class SceneBrowser extends StatefulWidget {
  const SceneBrowser({super.key, this.title, this.sceneFilter, this.header});
  final String? title;
  final Map<String, dynamic>? sceneFilter;
  final Widget? header;

  @override
  State<SceneBrowser> createState() => _SceneBrowserState();
}

class _SceneBrowserState extends State<SceneBrowser> {
  final _scroll = ScrollController();
  final _items = <Scene>[];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _done = false;
  String? _error;
  int _sort = 0;
  String _q = '';
  int _seed = DateTime.now().millisecondsSinceEpoch % 100000;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() {
      _items.clear();
      _page = 0;
      _done = false;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final c = context.read<AppState>().client!;
      final (_, key, dir) = _sorts[_sort];
      final r = await c.scenes(
        page: _page + 1,
        sort: key == 'random' ? 'random_$_seed' : key,
        direction: dir,
        query: _q,
        sceneFilter: widget.sceneFilter,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _total = r.total;
        _items.addAll(r.items);
        _done = r.items.isEmpty || _items.length >= r.total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(controller: _scroll, slivers: [
      if (widget.header != null) SliverToBoxAdapter(child: widget.header),
      if (widget.title != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(widget.title!, style: display(40)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('$_total', style: const TextStyle(color: Pal.dim, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: TextField(
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 450), () {
                _q = v;
                _reset();
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search scenes',
              prefixIcon: Icon(Icons.search_rounded, color: Pal.dim),
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _sorts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_sorts[i].$1),
              selected: _sort == i,
              showCheckmark: false,
              selectedColor: Pal.ember,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _sort == i ? Colors.black : Pal.text),
              onSelected: (_) {
                _sort = i;
                _seed = DateTime.now().millisecondsSinceEpoch % 100000;
                _reset();
              },
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      if (_error != null && _items.isEmpty)
        SliverFillRemaining(hasScrollBody: false, child: ErrorNote(_error!, onRetry: _reset))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisSpacing: 22,
              crossAxisSpacing: 16,
              childAspectRatio: 16 / 12.2,
            ),
            itemCount: _items.length,
            itemBuilder: (_, i) => SceneCard(_items[i], index: i),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Pal.ember))
                : (_items.isEmpty && !_loading && _error == null)
                    ? const Text('Nothing here.', style: TextStyle(color: Pal.dim))
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    ]);
  }
}
