import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'models.dart';
import 'screens/scene_screen.dart';
import 'theme.dart';

/// Network image that carries the Stash API key.
class LensImage extends StatelessWidget {
  const LensImage(this.url, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center});

  final String? url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final headers = context.read<AppState>().client?.headers ?? const {};
    if (url == null || url!.isEmpty) return const _Placeholder();
    return CachedNetworkImage(
      imageUrl: url!,
      httpHeaders: headers,
      fit: fit,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 350),
      placeholder: (_, __) => const _Placeholder(),
      errorWidget: (_, __, ___) => const _Placeholder(icon: true),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon = false});
  final bool icon;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Pal.raised, Pal.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: icon ? const Center(child: Icon(Icons.broken_image_outlined, color: Pal.dim)) : null,
      );
}

/// Concentric-ring mark used on the setup screen and as a loader.
class LensMark extends StatelessWidget {
  const LensMark({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _LensPainter()));
}

class _LensPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..color = Pal.text.withOpacity(0.9);
    canvas.drawCircle(c, r * 0.92, ring);
    ring.strokeWidth = r * 0.05;
    ring.color = Pal.dim.withOpacity(0.6);
    canvas.drawCircle(c, r * 0.62, ring);
    canvas.drawCircle(c, r * 0.28, Paint()..color = Pal.ember);
    final glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..color = Pal.gold;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.78), -2.5, 0.7, false, glint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class SceneCard extends StatelessWidget {
  const SceneCard(this.scene, {super.key, this.index = 0});
  final Scene scene;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => SceneScreen(scene: scene),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Hero(
              tag: 'scene-${scene.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  LensImage(scene.screenshot),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0xCC000000)],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _Pill(fmtDuration(scene.duration)),
                  ),
                  if (scene.quality.isNotEmpty) Positioned(left: 8, top: 8, child: _Pill(scene.quality, accent: true)),
                  if (scene.progress > 0.01)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: scene.progress,
                        minHeight: 3,
                        color: Pal.ember,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(scene.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 2),
          Text(
            [if (scene.studio != null) scene.studio!, if (scene.performers.isNotEmpty) scene.performers.map((p) => p.name).take(2).join(', ')].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Pal.dim, fontSize: 12),
          ),
        ],
      ),
    ).animate(delay: (40 * (index % 8)).ms).fadeIn(duration: 380.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: accent ? Pal.ember : Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating100, required this.onChanged});
  final int? rating100;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final stars = ((rating100 ?? 0) / 20).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final on = i < stars;
        return GestureDetector(
          onTap: () => onChanged(stars == i + 1 ? null : (i + 1) * 20),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded, key: ValueKey(on), color: on ? Pal.gold : Pal.dim, size: 28),
            ),
          ),
        );
      }),
    );
  }
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
            const Icon(Icons.cloud_off_rounded, color: Pal.dim, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Pal.dim)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ]),
        ),
      );
}
