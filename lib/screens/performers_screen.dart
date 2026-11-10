import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scenes_screen.dart';

class PerformersScreen extends StatefulWidget {
  const PerformersScreen({super.key});

  @override
  State<PerformersScreen> createState() => _PerformersScreenState();
}

class _PerformersScreenState extends State<PerformersScreen> {
  final _scroll = ScrollController();
  final _items = <Performer>[];
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  bool _favs = false;
  String _q = '';
  String? _error;
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
      final r = await context.read<AppState>().client!.performers(page: _page + 1, query: _q, favoritesOnly: _favs);
      if (!mounted) return;
      setState(() {
        _page++;
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
    return SafeArea(
      child: CustomScrollView(controller: _scroll, slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('People', style: display(40)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search_rounded, color: Pal.dim),
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: () {
                  _favs = !_favs;
                  _reset();
                },
                style: IconButton.styleFrom(backgroundColor: _favs ? Pal.ember : Pal.raised, foregroundColor: _favs ? Colors.black : Pal.dim),
                icon: Icon(_favs ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        if (_error != null && _items.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: ErrorNote(_error!, onRetry: _reset))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                childAspectRatio: 0.66,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) => _PerformerTile(_items[i], i),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Pal.ember)) : null),
          ),
        ),
      ]),
    );
  }
}

class _PerformerTile extends StatelessWidget {
  const _PerformerTile(this.p, this.index);
  final Performer p;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PerformerScreen(performer: p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'performer-${p.id}', child: LensImage(p.image, alignment: Alignment.topCenter)),
              if (p.favorite) const Positioned(top: 8, right: 8, child: Icon(Icons.favorite_rounded, color: Pal.ember, size: 18)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('${p.sceneCount} scenes', style: const TextStyle(color: Pal.dim, fontSize: 12)),
      ]),
    ).animate(delay: (30 * (index % 9)).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }
}

class PerformerScreen extends StatelessWidget {
  const PerformerScreen({super.key, required this.performer});
  final Performer performer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SceneBrowser(
          sceneFilter: {
            'performers': {
              'value': [performer.id],
              'modifier': 'INCLUDES_ALL',
            },
          },
          header: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
            child: Row(children: [
              const BackButton(),
              Hero(
                tag: 'performer-${performer.id}',
                child: ClipOval(child: SizedBox(width: 64, height: 64, child: LensImage(performer.image, alignment: Alignment.topCenter))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(performer.name, style: display(28), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${performer.sceneCount} scenes', style: const TextStyle(color: Pal.dim)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
