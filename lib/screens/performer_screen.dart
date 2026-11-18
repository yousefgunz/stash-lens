import 'package:flutter/material.dart';

import '../models.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scenes_screen.dart';

class PerformerScreen extends StatefulWidget {
  const PerformerScreen({super.key, required this.id});
  final int id;
  @override
  State<PerformerScreen> createState() => _PerformerScreenState();
}

class _PerformerScreenState extends State<PerformerScreen> {
  Map<String, dynamic>? _p;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await apiOf(context).performer(widget.id);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      body: _error != null
          ? SafeArea(child: Column(children: [Align(alignment: Alignment.centerLeft, child: BackButton()), Expanded(child: ErrorNote(_error!, onRetry: () {
              setState(() => _error = null);
              _load();
            }))]))
          : p == null
              ? const Spin()
              : SceneBrowser(
                  fixed: {'performer': widget.id},
                  header: _Header(p, widget.id),
                ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.p, this.id);
  final Map<String, dynamic> p;
  final int id;

  num? _num(String k) => p[k] as num?;
  String? _str(String k) {
    final v = p[k];
    return (v == null || v.toString().trim().isEmpty) ? null : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final api = apiOf(context);
    final name = (p['name'] ?? '').toString();
    final top = MediaQuery.of(context).padding.top;
    final sub = [
      if (_str('disambiguation') != null) _str('disambiguation')!,
      if (_num('age') != null) '${_num('age')!.toInt()} years',
      if (_str('country') != null) _str('country')!,
      if (_str('gender') != null) _str('gender')![0] + _str('gender')!.substring(1).toLowerCase().replaceAll('_', ' '),
    ].join('  ·  ');
    final stars = ((_num('rating') ?? 0) / 20).round();
    final fav = p['favorite'] == 1 || p['favorite'] == true;
    final tags = ((p['tags'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final studios = ((p['top_studios'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final topTags = ((p['top_tags'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final years = ((p['years'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final costars = ((p['costars'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final aliases = ((p['aliases'] as List?) ?? const []).map((e) => e.toString()).toList();
    final maxY = years.fold<int>(1, (a, b) => (b['n'] as num).toInt() > a ? (b['n'] as num).toInt() : a);
    final facts = <(String, String)>[
      if (_num('height') != null) ('Height', '${_num('height')!.toInt()} cm'),
      if (_str('ethnicity') != null) ('Ethnicity', _str('ethnicity')!),
      if (_str('eye_color') != null) ('Eyes', _str('eye_color')!),
      if (_str('measurements') != null) ('Measurements', _str('measurements')!),
      if (_str('career_length') != null) ('Career', _str('career_length')!),
      if (_str('tattoos') != null) ('Tattoos', _str('tattoos')!),
      if (_str('piercings') != null) ('Piercings', _str('piercings')!),
      if (_str('birthdate') != null) ('Born', _str('birthdate')!),
    ];

    Widget label(String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 10), child: Text(t, style: heading(19)));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 420,
        child: Stack(fit: StackFit.expand, children: [
          LImage(api.img('performer', id, w: 900), alignment: Alignment.topCenter, icon: Icons.person_rounded),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x88000000), Colors.transparent, Color(0xAA07080C), Pal.bg], stops: [0, 0.3, 0.75, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          ),
          Positioned(left: 6, top: top + 4, child: IconButton(onPressed: () => Navigator.maybePop(context), style: IconButton.styleFrom(backgroundColor: Colors.black38), icon: const Icon(Icons.arrow_back_rounded))),
          Positioned(
            left: 20,
            right: 20,
            bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: heading(40))),
                if (fav) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.favorite_rounded, color: Pal.a, size: 26)),
              ]),
              if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(sub, style: const TextStyle(color: Pal.mute, fontSize: 14))),
              if (stars > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Stars(stars, size: 18)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          _Stat('${_num('scenes')?.toInt() ?? 0}', 'scenes'),
          _Stat(fmtNum(_num('plays') ?? 0), 'plays'),
          _Stat(fmtNum(_num('o_count') ?? 0), 'favourites'),
          _Stat(fmtHours((_num('total_duration') ?? 0).toDouble()), 'footage'),
          _Stat(fmtSize(_num('total_size') ?? 0), 'on disk'),
          if (_str('first_date') != null)
            _Stat('${_str('first_date')!.substring(0, 4)}–${(_str('last_date') ?? _str('first_date')!).substring(0, 4)}', 'active'),
        ]),
      ),
      if (_str('details') != null) Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: Text(_str('details')!, style: const TextStyle(color: Pal.mute, height: 1.5))),
      if (aliases.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Text('Also known as ${aliases.join(', ')}', style: const TextStyle(color: Pal.dim, height: 1.4))),
      if (facts.isNotEmpty) ...[
        label('Details'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 10, runSpacing: 10, children: [for (final f in facts) _Fact(f.$1, f.$2)]),
        ),
      ],
      if (tags.isNotEmpty) ...[
        label('Tags'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in tags) LChip(t['name'].toString(), onTap: () => openScenes(context, title: '#${t['name']}', filters: {'tag': t['id']})),
          ]),
        ),
      ],
      if (studios.isNotEmpty) ...[
        label('Top studios'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in studios)
              LChip('${s['name']}  ${s['n']}', onTap: () => openScenes(context, title: s['name'].toString(), filters: {'studio': s['id']})),
          ]),
        ),
      ],
      if (topTags.isNotEmpty) ...[
        label('Most common in their scenes'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in topTags)
              LChip('${t['name']}  ${t['n']}', onTap: () => openScenes(context, title: '$name · ${t['name']}', filters: {'performer': id, 'tag': t['id']})),
          ]),
        ),
      ],
      if (years.length > 1) ...[
        label('Scenes by year'),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: years.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final y = years[i]['y'].toString();
              final n = (years[i]['n'] as num).toInt();
              return GestureDetector(
                onTap: () => openScenes(context, title: '$name · $y', filters: {'performer': id, 'year': y}),
                child: SizedBox(
                  width: 36,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('$n', style: const TextStyle(fontSize: 11, color: Pal.mute, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Container(height: 8 + 50 * n / maxY, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF3D5A), Color(0xFFFFB14D)], begin: Alignment.bottomCenter, end: Alignment.topCenter), borderRadius: BorderRadius.circular(5))),
                    const SizedBox(height: 4),
                    Text(y.length == 4 ? "'${y.substring(2)}" : y, style: const TextStyle(fontSize: 11, color: Pal.dim)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
      if (costars.isNotEmpty) ...[
        label('Frequent co-stars'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: costars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final c = costars[i];
              return GestureDetector(
                onTap: () => openPerformer(context, (c['id'] as num).toInt()),
                child: SizedBox(
                  width: 74,
                  child: Column(children: [
                    Avatar((c['id'] as num).toInt(), size: 70),
                    const SizedBox(height: 6),
                    Text(c['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${c['n']}×', style: const TextStyle(fontSize: 11, color: Pal.dim)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
      label('Scenes'),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.v, this.l);
  final String v;
  final String l;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          GradText(v, heading(19)),
          const SizedBox(height: 2),
          Text(l, style: const TextStyle(color: Pal.mute, fontSize: 11.5)),
        ]),
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(k, style: const TextStyle(color: Pal.dim, fontSize: 11)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        ]),
      );
}
