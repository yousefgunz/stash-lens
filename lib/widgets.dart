import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'models.dart';
import 'nav.dart';
import 'state.dart';
import 'theme.dart';

LensApi apiOf(BuildContext c) => c.read<AppState>().api!;

/// Network image that carries the Stash Lens password. A 204 (no image) falls back to a gradient.
class LImage extends StatelessWidget {
  const LImage(this.url, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.icon});
  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (url == null) return _Ph(icon: icon);
    return CachedNetworkImage(
      imageUrl: url!,
      httpHeaders: apiOf(context).headers,
      fit: fit,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (_, __) => const _Ph(),
      errorWidget: (_, __, ___) => _Ph(icon: icon),
    );
  }
}

class _Ph extends StatelessWidget {
  const _Ph({this.icon});
  final IconData? icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Pal.bg4, Pal.bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: icon == null ? null : Center(child: Icon(icon, color: Pal.dim, size: 28)),
      );
}

/// The logo tile from the web app's nav bar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 26});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: Pal.grad,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [BoxShadow(color: const Color(0xFFFF5046).withOpacity(0.5), blurRadius: size * 0.7, offset: Offset(0, size * 0.16))],
        ),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.78),
      );
}

class GradText extends StatelessWidget {
  const GradText(this.text, this.style, {super.key});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => Pal.grad.createShader(r),
        blendMode: BlendMode.srcIn,
        child: Text(text, style: style.copyWith(color: Colors.white)),
      );
}

class GradButton extends StatelessWidget {
  const GradButton({super.key, required this.label, required this.onTap, this.icon, this.height = 50, this.expand = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        gradient: onTap == null ? null : Pal.grad,
        color: onTap == null ? Pal.bg4 : null,
        borderRadius: BorderRadius.circular(99),
        boxShadow: onTap == null ? null : [BoxShadow(color: const Color(0xFFFF4757).withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 6))],
      ),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 8)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5))),
      ]),
    );
    return GestureDetector(onTap: onTap, child: child);
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap, this.icon, this.height = 50});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: Pal.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
      );
}

class LChip extends StatelessWidget {
  const LChip(this.label, {super.key, this.onTap, this.accent = false, this.icon, this.selected = false});
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool selected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final on = accent || selected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: on ? Pal.grad : null,
          color: on ? null : Pal.bg3,
          borderRadius: BorderRadius.circular(99),
          border: on ? null : Border.all(color: Pal.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: on ? Colors.white : Pal.mute), const SizedBox(width: 5)],
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? Colors.white : Pal.ink)),
        ]),
      ),
    );
  }
}

class ResBadge extends StatelessWidget {
  const ResBadge(this.res, {super.key});
  final String? res;
  @override
  Widget build(BuildContext context) {
    if (res == null || res!.isEmpty) return const SizedBox.shrink();
    final hot = res == '8K' || res == '6K' || res == '4K' || res == '1440p';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: hot ? Pal.grad : null,
        color: hot ? null : Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(res!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class Stars extends StatelessWidget {
  const Stars(this.stars, {super.key, this.size = 14});
  final int stars;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < stars ? Pal.gold : Pal.dim),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.onMore, this.pad = 20});
  final String text;
  final VoidCallback? onMore;
  final double pad;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
        child: Row(children: [
          Expanded(child: Text(text, style: heading(21))),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: const Row(children: [
                Text('See all', style: TextStyle(color: Pal.mute, fontWeight: FontWeight.w600, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: Pal.mute, size: 18),
              ]),
            ),
        ]),
      );
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, color: Pal.dim, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Pal.mute, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              GhostButton(label: 'Try again', icon: Icons.refresh_rounded, onTap: onRetry!, height: 42),
            ],
          ]),
        ),
      );
}

class Spin extends StatelessWidget {
  const Spin({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Pal.a)));
}

// ───────────────────────────── cards ─────────────────────────────

class SceneCard extends StatelessWidget {
  const SceneCard(this.s, {super.key, this.index = 0, this.rank});
  final Scene s;
  final int index;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final prog = context.select<AppState, ProgEntry?>((a) => a.progOf(s.id));
    final sub = [if (s.studio != null) s.studio!, if (s.year != null) s.year!].join('  ·  ');
    final names = s.performers.map((p) => p.name).take(2).join(', ');
    final card = GestureDetector(
      onTap: () => openScene(context, s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(fit: StackFit.expand, children: [
                LImage(api.img('scene', s.id, w: 560)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, Color(0xCC000000)], begin: Alignment(0, 0.1), end: Alignment.bottomCenter),
                  ),
                ),
                Positioned(left: 8, top: 8, child: ResBadge(s.res)),
                if (s.duration > 0)
                  Positioned(
                    right: 8,
                    bottom: prog != null ? 10 : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(5)),
                      child: Text(fmtTime(s.duration), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (rank != null)
                  Positioned(left: 10, bottom: 2, child: GradText('$rank', heading(44, w: FontWeight.w900))),
                if (s.stars > 0)
                  Positioned(right: 8, top: 8, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, size: 12, color: Pal.gold),
                      const SizedBox(width: 2),
                      Text('${s.stars}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                  )),
                if (prog != null && prog.d > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(value: (prog.t / prog.d).clamp(0.0, 1.0), minHeight: 3.5, color: Pal.a, backgroundColor: Colors.white24),
                  ),
              ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.22, fontSize: 14.5)),
        const SizedBox(height: 2),
        Text(names.isNotEmpty ? names : sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.mute, fontSize: 12.5)),
        if (names.isNotEmpty && sub.isNotEmpty)
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.dim, fontSize: 12)),
      ]),
    );
    if (index > 7) return card;
    return card.animate(delay: (45 * index).ms).fadeIn(duration: 380.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }
}

class PerformerCard extends StatelessWidget {
  const PerformerCard(this.p, {super.key, this.index = 0});
  final Performer p;
  final int index;

  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final sub = p.note ?? [if (p.age != null) '${p.age}', '${p.scenes} scenes'].join('  ·  ');
    final card = GestureDetector(
      onTap: () => openPerformer(context, p.id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              LImage(api.img('performer', p.id, w: 360), alignment: Alignment.topCenter, icon: Icons.person_rounded),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0x99000000)], begin: Alignment(0, 0.4), end: Alignment.bottomCenter)),
              ),
              if (p.favorite) const Positioned(top: 8, right: 8, child: Icon(Icons.favorite_rounded, color: Pal.a, size: 18)),
              if (p.stars > 0) Positioned(left: 8, bottom: 8, child: Stars(p.stars, size: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 7),
        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.mute, fontSize: 12)),
      ]),
    );
    if (index > 9) return card;
    return card.animate(delay: (35 * index).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }
}

class StudioTile extends StatelessWidget {
  const StudioTile(this.s, {super.key});
  final Studio s;
  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    return GestureDetector(
      onTap: () => openScenes(context, title: s.name, filters: {'studio': s.id}),
      child: Container(
        decoration: BoxDecoration(color: Pal.bg3, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 38),
            child: LImage(api.img('studio', s.id, w: 360), fit: BoxFit.contain),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 9),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xEE07080C)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: Row(children: [
                Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
                if (s.favorite) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.favorite_rounded, color: Pal.a, size: 14)),
                const SizedBox(width: 6),
                Text('${s.scenes}', style: const TextStyle(color: Pal.mute, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class TagTile extends StatelessWidget {
  const TagTile(this.t, this.maxScenes, {super.key});
  final TagItem t;
  final int maxScenes;
  @override
  Widget build(BuildContext context) {
    final heat = (t.scenes / (maxScenes <= 0 ? 1 : maxScenes)).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => openScenes(context, title: '#${t.name}', filters: {'tag': t.id}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(Pal.bg3, const Color(0xFF3A1D24), heat),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Color.lerp(Pal.line, Pal.a.withOpacity(0.6), heat)!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (t.favorite) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.favorite_rounded, color: Pal.a, size: 13)),
          Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(width: 7),
          Text('${t.scenes}', style: const TextStyle(color: Pal.mute, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Round portrait; [face] is the percent position from /api/cast (the web app's face framing).
class Avatar extends StatelessWidget {
  const Avatar(this.id, {super.key, this.size = 64, this.face});
  final int id;
  final double size;
  final (double, double)? face;
  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final al = face == null ? Alignment.topCenter : Alignment(face!.$1 / 50 - 1, face!.$2 / 50 - 1);
    return ClipOval(child: SizedBox(width: size, height: size, child: LImage(api.img('performer', id, w: (size * 3).round()), alignment: al, icon: Icons.person_rounded)));
  }
}

/// Horizontal rail with its own loader. Hides itself when there's nothing to show.
class Rail extends StatefulWidget {
  const Rail({super.key, required this.title, required this.load, this.onMore, this.height = 236});
  final String title;
  final Future<List<Widget>> Function() load;
  final VoidCallback? onMore;
  final double height;
  @override
  State<Rail> createState() => _RailState();
}

class _RailState extends State<Rail> {
  late Future<List<Widget>> _f = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Widget>>(
      future: _f,
      builder: (context, snap) {
        if (snap.hasData && snap.data!.isEmpty) return const SizedBox.shrink();
        Widget body;
        if (snap.hasError) {
          body = SizedBox(height: 90, child: ErrorNote(snap.error.toString(), onRetry: () => setState(() => _f = widget.load())));
        } else if (!snap.hasData) {
          body = SizedBox(
            height: widget.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => Container(width: 250, margin: const EdgeInsets.only(bottom: 70), decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(12))),
            ),
          );
        } else {
          final items = snap.data!;
          body = SizedBox(
            height: widget.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => items[i],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle(widget.title, onMore: widget.onMore), body]),
        );
      },
    );
  }
}
