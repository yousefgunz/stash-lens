import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'performers_screen.dart';
import 'player_screen.dart';

class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key, required this.scene});
  final Scene scene;

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  late Scene scene = widget.scene;

  Future<void> _play() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(scene: scene)));
    // Refresh so the resume position and play count are current.
    try {
      final fresh = await context.read<AppState>().client!.scene(scene.id);
      if (mounted) setState(() => scene = fresh);
    } catch (_) {}
  }

  Future<void> _rate(int? v) async {
    setState(() => scene.rating100 = v);
    try {
      await context.read<AppState>().client!.setRating(scene.id, v);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save rating: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final resuming = scene.resumeTime > 5;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: Pal.bg,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'scene-${scene.id}', child: LensImage(scene.screenshot)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0x66000000), Colors.transparent, Pal.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: _play,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Pal.ember, boxShadow: [BoxShadow(color: Pal.ember.withOpacity(0.5), blurRadius: 30)]),
                    child: const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.black),
                  ),
                ).animate().scale(begin: const Offset(0.7, 0.7), duration: 400.ms, curve: Curves.easeOutBack),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList.list(children: [
            Text(scene.title, style: display(30)).animate().fadeIn().slideY(begin: 0.08),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (scene.studio != null) Chip(label: Text(scene.studio!)),
              if (scene.date != null) Chip(label: Text(scene.date!)),
              Chip(label: Text(fmtDuration(scene.duration))),
              if (scene.quality.isNotEmpty) Chip(label: Text(scene.quality)),
              if (scene.playCount > 0) Chip(label: Text('Played ${scene.playCount}×')),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(resuming ? 'Resume from ${fmtDuration(scene.resumeTime)}' : 'Play', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: Pal.ember,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            StarRating(rating100: scene.rating100, onChanged: _rate),
            if (scene.performers.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Cast', style: display(20)),
              const SizedBox(height: 12),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: scene.performers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) {
                    final p = scene.performers[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PerformerScreen(performer: p))),
                      child: SizedBox(
                        width: 72,
                        child: Column(children: [
                          ClipOval(child: SizedBox(width: 72, height: 72, child: LensImage(p.image, alignment: Alignment.topCenter))),
                          const SizedBox(height: 6),
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (scene.tags.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(spacing: 8, runSpacing: 8, children: scene.tags.map((t) => Chip(label: Text(t))).toList()),
            ],
            if (scene.details != null && scene.details!.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(scene.details!, style: const TextStyle(color: Pal.dim, height: 1.5)),
            ],
          ]),
        ),
      ]),
    );
  }
}
