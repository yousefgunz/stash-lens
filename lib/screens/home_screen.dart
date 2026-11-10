import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppState>().client!;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.only(top: 20, bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const LensMark(size: 34),
            const SizedBox(width: 12),
            Text('Stash Lens', style: display(30)),
          ]),
        ),
        const SizedBox(height: 24),
        _Rail(
          title: 'Continue watching',
          future: () => c.scenes(
            perPage: 12,
            sort: 'last_played_at',
            sceneFilter: {
              'resume_time': {'value': 1, 'modifier': 'GREATER_THAN'},
            },
          ),
        ),
        _Rail(title: 'Recently added', future: () => c.scenes(perPage: 14, sort: 'created_at')),
        _Rail(
          title: 'Highest rated',
          future: () => c.scenes(perPage: 14, sort: 'rating', sceneFilter: {
            'rating100': {'value': 1, 'modifier': 'GREATER_THAN'},
          }),
        ),
        _Rail(title: 'Something random', future: () => c.scenes(perPage: 14, sort: 'random_${DateTime.now().millisecondsSinceEpoch % 100000}')),
      ]),
    );
  }
}

class _Rail extends StatefulWidget {
  const _Rail({required this.title, required this.future});
  final String title;
  final Future<Paged<Scene>> Function() future;

  @override
  State<_Rail> createState() => _RailState();
}

class _RailState extends State<_Rail> {
  late Future<Paged<Scene>> _f = widget.future();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Paged<Scene>>(
      future: _f,
      builder: (context, snap) {
        if (snap.hasData && snap.data!.items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(widget.title, style: display(22)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: snap.hasError
                  ? ErrorNote(snap.error.toString(), onRetry: () => setState(() => _f = widget.future()))
                  : !snap.hasData
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (_, __) => AspectRatio(
                            aspectRatio: 16 / 9,
                            child: DecoratedBox(decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(12))),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: snap.data!.items.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (_, i) => SizedBox(width: 268, child: SceneCard(snap.data!.items[i], index: i)),
                        ),
            ),
          ]),
        );
      },
    );
  }
}
