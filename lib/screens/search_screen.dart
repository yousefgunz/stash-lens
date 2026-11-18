import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

/// One box searching scenes, performers, studios and tags at once.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  Timer? _debounce;
  int _rq = 0;
  bool _loading = false;
  String? _error;
  String _q = '';
  Paged<Scene>? _scenes;
  Paged<Performer>? _perfs;
  Paged<Studio>? _studios;
  Paged<TagItem>? _tags;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    final rq = ++_rq;
    if (q.isEmpty) {
      setState(() {
        _q = '';
        _scenes = null;
        _perfs = null;
        _studios = null;
        _tags = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _q = q;
    });
    final api = apiOf(context);
    try {
      final r = await Future.wait<dynamic>([
        api.scenes({'q': q, 'per': 12, 'sort': 'created'}),
        api.performers({'q': q, 'per': 12, 'sort': 'scenes', 'dir': 'desc'}),
        api.studios({'q': q, 'per': 8}),
        api.tags({'q': q, 'per': 24, 'used': 1}),
      ]);
      if (!mounted || rq != _rq) return;
      setState(() {
        _scenes = r[0] as Paged<Scene>;
        _perfs = r[1] as Paged<Performer>;
        _studios = r[2] as Paged<Studio>;
        _tags = r[3] as Paged<TagItem>;
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
    final empty = _scenes != null && _scenes!.items.isEmpty && _perfs!.items.isEmpty && _studios!.items.isEmpty && _tags!.items.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search everything',
                    prefixIcon: const Icon(Icons.search_rounded, color: Pal.dim),
                    suffixIcon: _ctl.text.isEmpty ? null : IconButton(onPressed: () {
                      _ctl.clear();
                      _run('');
                    }, icon: const Icon(Icons.close_rounded, color: Pal.dim)),
                    isDense: true,
                  ),
                ),
              ),
            ]),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2, color: Pal.a, backgroundColor: Colors.transparent),
          Expanded(
            child: _error != null
                ? ErrorNote(_error!, onRetry: () => _run(_q))
                : _scenes == null
                    ? const Center(child: Text('Scenes, performers, studios and tags.', style: TextStyle(color: Pal.dim)))
                    : empty
                        ? Center(child: Text('Nothing found for “$_q”.', style: const TextStyle(color: Pal.mute)))
                        : ListView(padding: const EdgeInsets.only(bottom: 40, top: 8), children: [
                            if (_perfs!.items.isNotEmpty) ...[
                              SectionTitle('Performers · ${_perfs!.total}'),
                              SizedBox(
                                height: 104,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: _perfs!.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                                  itemBuilder: (_, i) {
                                    final p = _perfs!.items[i];
                                    return GestureDetector(
                                      onTap: () => openPerformer(context, p.id),
                                      child: SizedBox(
                                        width: 74,
                                        child: Column(children: [
                                          Avatar(p.id, size: 70),
                                          const SizedBox(height: 6),
                                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 22),
                            ],
                            if (_studios!.items.isNotEmpty) ...[
                              SectionTitle('Studios · ${_studios!.total}'),
                              SizedBox(
                                height: 100,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: _studios!.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (_, i) => SizedBox(width: 170, child: StudioTile(_studios!.items[i])),
                                ),
                              ),
                              const SizedBox(height: 22),
                            ],
                            if (_tags!.items.isNotEmpty) ...[
                              SectionTitle('Tags · ${_tags!.total}'),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Wrap(spacing: 8, runSpacing: 8, children: [for (final t in _tags!.items) TagTile(t, _tags!.extra['max_scenes'] as int)]),
                              ),
                              const SizedBox(height: 22),
                            ],
                            if (_scenes!.items.isNotEmpty) ...[
                              SectionTitle('Scenes · ${fmtNum(_scenes!.total)}', onMore: _scenes!.total > _scenes!.items.length ? () => openScenes(context, title: '“$_q”', filters: {'q': _q}) : null),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: LayoutBuilder(builder: (context, c) {
                                  final cols = c.maxWidth < 560 ? 2 : (c.maxWidth / 300).floor();
                                  const gap = 14.0;
                                  final w = (c.maxWidth - gap * (cols - 1)) / cols;
                                  return Wrap(spacing: gap, runSpacing: 18, children: [
                                    for (var i = 0; i < _scenes!.items.length; i++) SizedBox(width: w, child: SceneCard(_scenes!.items[i], index: 99)),
                                  ]);
                                }),
                              ),
                            ],
                          ]),
          ),
        ]),
      ),
    );
  }
}
