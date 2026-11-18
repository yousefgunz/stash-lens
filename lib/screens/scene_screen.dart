import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key, this.preview, this.sceneId}) : assert(preview != null || sceneId != null);
  final Scene? preview;
  final int? sceneId;
  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  Scene? _s;
  String? _error;
  List<Scene> _similar = [];
  Map<int, (double, double)> _faces = {};
  int _fileId = 0; // 0 = primary

  int get _id => widget.sceneId ?? widget.preview!.id;

  @override
  void initState() {
    super.initState();
    _s = widget.preview;
    _load();
  }

  Future<void> _load() async {
    final api = apiOf(context);
    try {
      final s = await api.scene(_id);
      if (!mounted) return;
      setState(() {
        _s = s;
        _error = null;
      });
      _loadSimilar(s);
      api.cast(s.id).then((f) {
        if (mounted) setState(() => _faces = f);
      });
    } catch (e) {
      if (mounted && _s == null) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadSimilar(Scene s) async {
    final api = apiOf(context);
    final q = <String, dynamic>{'sort': 'random', 'per': 14};
    if (s.performers.isNotEmpty) {
      q['performer'] = s.performers.first.id;
    } else if (s.tags.isNotEmpty) {
      q['tag'] = s.tags.first.id;
    } else if (s.studioId != null) {
      q['studio'] = s.studioId;
    } else {
      return;
    }
    try {
      final d = await api.scenes(q);
      if (mounted) setState(() => _similar = d.items.where((x) => x.id != s.id).toList());
    } catch (_) {}
  }

  double _resumeAt(Scene s, AppState app) {
    final local = app.progOf(s.id)?.t.toDouble() ?? 0;
    final r = local > s.resumeTime ? local : s.resumeTime;
    return (r > 10 && (s.duration <= 0 || r < s.duration - 15)) ? r : 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft, child: BackButton()),
            Expanded(child: _error != null ? ErrorNote(_error!, onRetry: _load) : const Spin()),
          ]),
        ),
      );
    }
    final api = apiOf(context);
    final app = context.watch<AppState>();
    final resume = _resumeAt(s, app);
    final top = MediaQuery.of(context).padding.top;
    final files = s.files;
    final fid = _fileId == 0 ? null : _fileId;

    Widget h(String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 12), child: Text(t, style: heading(19)));

    return Scaffold(
      body: ListView(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 40), children: [
        // ── backdrop ──
        SizedBox(
          height: 300 + top,
          child: Stack(fit: StackFit.expand, children: [
            LImage(s.hero ? api.hero(s.id) : api.img('scene', s.id, w: 1280), alignment: Alignment.topCenter),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x99000000), Colors.transparent, Color(0x9907080C), Pal.bg], stops: [0, 0.3, 0.78, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            ),
            Positioned(left: 6, top: top + 4, child: IconButton(onPressed: () => Navigator.maybePop(context), style: IconButton.styleFrom(backgroundColor: Colors.black38), icon: const Icon(Icons.arrow_back_rounded))),
            Center(
              child: GestureDetector(
                onTap: () => playScene(context, s, startAt: resume > 0 ? resume : null, fileId: fid, queue: _similar),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(gradient: Pal.grad, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Pal.a.withOpacity(0.5), blurRadius: 30)]),
                  child: const Icon(Icons.play_arrow_rounded, size: 46, color: Colors.white),
                ),
              ).animate().scale(begin: const Offset(0.7, 0.7), duration: 420.ms, curve: Curves.easeOutBack),
            ),
            if (resume > 0 && s.duration > 0)
              Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator(value: (resume / s.duration).clamp(0.0, 1.0), minHeight: 4, color: Pal.a, backgroundColor: Colors.white24)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, style: heading(32)).animate().fadeIn().slideY(begin: 0.06),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (s.studio != null) LChip(s.studio!, icon: Icons.business_rounded, onTap: () => openScenes(context, title: s.studio!, filters: {'studio': s.studioId})),
              if (s.date != null && s.date!.isNotEmpty) LChip(s.date!, icon: Icons.event_rounded),
              LChip(fmtTime(s.duration), icon: Icons.schedule_rounded),
              if (s.res != null) LChip(s.res!, accent: s.isHigh),
              if (s.vcodec != null) LChip(s.vcodec!.toUpperCase()),
              if (s.size > 0) LChip(fmtSize(s.size)),
              if (s.organized) const LChip('Organized', icon: Icons.check_circle_outline_rounded),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              if (s.stars > 0) ...[Stars(s.stars, size: 20), const SizedBox(width: 14)],
              if (s.playCount > 0) Text('${s.playCount} plays', style: const TextStyle(color: Pal.mute, fontSize: 13)),
              if (s.oCount > 0) ...[
                const SizedBox(width: 14),
                const Icon(Icons.favorite_rounded, size: 14, color: Pal.a),
                const SizedBox(width: 4),
                Text('${s.oCount}', style: const TextStyle(color: Pal.mute, fontSize: 13)),
              ],
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: GradButton(
                  label: resume > 0 ? 'Resume from ${fmtTime(resume)}' : 'Play',
                  icon: Icons.play_arrow_rounded,
                  height: 54,
                  expand: true,
                  onTap: () => playScene(context, s, startAt: resume > 0 ? resume : null, fileId: fid, queue: _similar),
                ),
              ),
              if (resume > 0) ...[
                const SizedBox(width: 10),
                GhostButton(label: 'Start over', height: 54, onTap: () => playScene(context, s, startAt: 0, fileId: fid, queue: _similar)),
              ],
            ]),
            if (files.length > 1) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _fileId,
                    isExpanded: true,
                    dropdownColor: Pal.bg3,
                    icon: const Icon(Icons.expand_more_rounded, color: Pal.mute),
                    items: [
                      for (var fi = 0; fi < files.length; fi++)
                        DropdownMenuItem(
                          value: fi == 0 ? 0 : files[fi].id,
                          child: Text('${files[fi].res ?? '${files[fi].height}p'} · ${(files[fi].vcodec ?? '').toUpperCase()} · ${fmtSize(files[fi].size)}${fi == 0 ? '  (default)' : ''}', style: const TextStyle(fontSize: 14)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _fileId = v ?? 0),
                  ),
                ),
              ),
            ],
          ]),
        ),
        if (s.performers.isNotEmpty) ...[
          h('Cast'),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: s.performers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final p = s.performers[i];
                return GestureDetector(
                  onTap: () => openPerformer(context, p.id),
                  child: SizedBox(
                    width: 82,
                    child: Column(children: [
                      Avatar(p.id, size: 78, face: _faces[p.id]),
                      const SizedBox(height: 6),
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      if (p.age != null) Text('${p.age} at release', maxLines: 1, style: const TextStyle(fontSize: 11, color: Pal.dim)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
        if ((s.details ?? '').trim().isNotEmpty || s.director != null || s.code != null) ...[
          h('About'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((s.details ?? '').trim().isNotEmpty) Text(s.details!, style: const TextStyle(color: Pal.mute, height: 1.5, fontSize: 14.5)),
              if (s.director != null && s.director!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Director: ${s.director}', style: const TextStyle(color: Pal.mute))),
              if (s.code != null && s.code!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Code: ${s.code}', style: const TextStyle(color: Pal.mute))),
            ]),
          ),
        ],
        if (s.markers.isNotEmpty) ...[
          h('Chapters · ${s.markers.length}'),
          for (final m in s.markers)
            InkWell(
              onTap: () => playScene(context, s, startAt: m.seconds, fileId: fid, queue: _similar),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: Pal.bg3, borderRadius: BorderRadius.circular(8)),
                    child: Text(fmtTime(m.seconds), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Pal.a2)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(m.title.isEmpty ? (m.tag ?? 'Marker') : m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (m.tag != null && m.tag!.isNotEmpty && m.title.isNotEmpty) LChip(m.tag!),
                ]),
              ),
            ),
        ],
        if (s.tags.isNotEmpty) ...[
          h('Tags'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in s.tags) LChip(t.name, onTap: () => openScenes(context, title: '#${t.name}', filters: {'tag': t.id})),
            ]),
          ),
        ],
        if (_similar.isNotEmpty) ...[
          const SizedBox(height: 26),
          SectionTitle('More like this'),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _similar.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(width: 260, child: SceneCard(_similar[i], index: i)),
            ),
          ),
        ],
        if (s.detailed) ...[
          h('History'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _History(s),
          ),
          h(files.length > 1 ? 'Files' : 'File'),
          for (final f in files) _FileCard(f),
          if (s.urls.isNotEmpty) ...[
            h('Links'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final u in s.urls) Padding(padding: const EdgeInsets.only(bottom: 6), child: SelectableText(u, style: const TextStyle(color: Pal.a2, fontSize: 13)))]),
            ),
          ],
        ],
      ]),
    );
  }
}

class _History extends StatelessWidget {
  const _History(this.s);
  final Scene s;
  @override
  Widget build(BuildContext context) {
    String d(String v) => v.length >= 10 ? v.substring(0, 10) : v;
    final views = s.viewDates;
    final o = s.oDates;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(views.isEmpty ? 'Never played' : 'Played ${s.playCount > views.length ? s.playCount : views.length}×  ·  last ${d(views.first)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (views.length > 1) ...[
          const SizedBox(height: 8),
          Text(views.take(8).map(d).join('   '), style: const TextStyle(color: Pal.dim, fontSize: 12.5, height: 1.5)),
        ],
        if (o.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.favorite_rounded, size: 15, color: Pal.a),
            const SizedBox(width: 6),
            Text('Favourited ${s.oCount > o.length ? s.oCount : o.length}×', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(o.take(8).map(d).join('   '), style: const TextStyle(color: Pal.dim, fontSize: 12.5, height: 1.5)),
        ],
        const SizedBox(height: 12),
        const Text('Read-only view: plays and ratings are changed in Stash itself.', style: TextStyle(color: Pal.dim, fontSize: 11.5)),
      ]),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard(this.f);
  final SceneFile f;
  @override
  Widget build(BuildContext context) {
    Widget row(String k, String? v) => (v == null || v.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 92, child: Text(k, style: const TextStyle(color: Pal.dim, fontSize: 12.5))),
              Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, height: 1.3))),
            ]),
          );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.basename, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        row('Path', f.path),
        row('Resolution', '${f.width}×${f.height}${f.res != null ? '  (${f.res})' : ''}'),
        row('Video', [f.vcodec, if (f.fps > 0) '${f.fps.toStringAsFixed(f.fps % 1 == 0 ? 0 : 2)} fps', if (f.bitrate > 0) '${(f.bitrate / 1e6).toStringAsFixed(1)} Mbps'].whereType<String>().join(' · ')),
        row('Audio', f.acodec),
        row('Container', f.format),
        row('Size', fmtSize(f.size)),
        row('Duration', fmtTime(f.duration)),
        for (final fp in f.fingerprints) row('Hash', fp),
      ]),
    );
  }
}
