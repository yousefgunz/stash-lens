import 'package:flutter/material.dart';

import '../models.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

/// Library statistics: the web app's overview dashboard.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await apiOf(context).overview();
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Map<String, dynamic>> _l(String k) => ((_d?[k] as List?) ?? const []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text('Library', style: heading(24))),
      body: _error != null
          ? ErrorNote(_error!, onRetry: () {
              setState(() => _error = null);
              _load();
            })
          : d == null
              ? const Spin()
              : _body(d),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final counts = (d['counts'] as Map).cast<String, dynamic>();
    final total = ((d['scene_total'] as num?) ?? 0).toInt();
    final ratings = ((d['ratings'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final byYear = _l('by_year');
    final byMonth = _l('by_month');
    final res = _l('resolutions');
    final codecs = _l('codecs');
    final genders = _l('genders');
    final maxRating = ratings.fold<int>(1, (a, b) => b > a ? b : a);
    final maxYear = byYear.fold<int>(1, (a, b) => (b['n'] as num).toInt() > a ? (b['n'] as num).toInt() : a);
    final maxMonth = byMonth.fold<int>(1, (a, b) => (b['n'] as num).toInt() > a ? (b['n'] as num).toInt() : a);
    final resTotal = res.fold<int>(0, (a, b) => a + (b['n'] as num).toInt());

    Widget h(String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 12), child: Text(t, style: heading(20)));

    Widget big(String v, String l) => Container(
          width: (MediaQuery.of(context).size.width - 50) / 2,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: GradText(v, heading(28))),
            const SizedBox(height: 4),
            Text(l, style: const TextStyle(color: Pal.mute, fontSize: 12.5)),
          ]),
        );

    Widget barList(List<Map<String, dynamic>> items, {required void Function(Map<String, dynamic>) onTap}) {
      final mx = items.fold<int>(1, (a, b) => (b['n'] as num).toInt() > a ? (b['n'] as num).toInt() : a);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          for (final it in items.take(10))
            InkWell(
              onTap: () => onTap(it),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 118, child: Text(it['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (it['n'] as num) / mx, minHeight: 8, color: Pal.a, backgroundColor: Pal.bg3),
                    ),
                  ),
                  SizedBox(width: 42, child: Text('${it['n']}', textAlign: TextAlign.right, style: const TextStyle(color: Pal.mute, fontWeight: FontWeight.w700, fontSize: 12.5))),
                ]),
              ),
            ),
        ]),
      );
    }

    Widget columns(List<Map<String, dynamic>> items, String key, int mx, {double h = 90, void Function(Map<String, dynamic>)? onTap, bool short = false}) => SizedBox(
          height: h + 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: short ? 5 : 8),
            itemBuilder: (_, i) {
              final it = items[i];
              final n = (it['n'] as num).toInt();
              final label = it[key].toString();
              return GestureDetector(
                onTap: onTap == null ? null : () => onTap(it),
                child: SizedBox(
                  width: short ? 22 : 36,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (!short) Text('$n', style: const TextStyle(fontSize: 10.5, color: Pal.mute, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Container(
                      height: 4 + h * n / mx,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF3D5A), Color(0xFFFFB14D)], begin: Alignment.bottomCenter, end: Alignment.topCenter), borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 4),
                    Text(short ? label.substring(label.length - 2) : (label.length == 4 ? "'${label.substring(2)}" : label), style: const TextStyle(fontSize: 10.5, color: Pal.dim)),
                  ]),
                ),
              );
            },
          ),
        );

    return ListView(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 40), children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          big(fmtNum(total), 'scenes'),
          big(fmtHours(((d['duration'] as num?) ?? 0).toDouble()), 'of footage'),
          big(fmtSize((d['size'] as num?) ?? 0), 'on disk'),
          big(fmtNum((d['plays_total'] as num?) ?? 0), 'plays'),
          big(fmtNum((d['o_total'] as num?) ?? 0), 'favourite marks'),
          big('${d['organized']}', 'organized'),
          big(fmtNum(counts['performers'] ?? 0), 'performers'),
          big(fmtNum(counts['studios'] ?? 0), 'studios'),
          big(fmtNum(counts['tags'] ?? 0), 'tags'),
          big(fmtNum(counts['markers'] ?? 0), 'markers'),
        ]),
      ),
      h('Resolution'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(height: 14, child: Row(children: [for (final r in res) Expanded(flex: (r['n'] as num).toInt().clamp(1, 1 << 30), child: GestureDetector(onTap: () => openScenes(context, title: r['label'].toString(), filters: {'res': r['label']}), child: Container(color: Pal.resColors[r['label']] ?? Pal.dim)))])),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final r in res)
              GestureDetector(
                onTap: () => openScenes(context, title: r['label'].toString(), filters: {'res': r['label']}),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: Pal.resColors[r['label']] ?? Pal.dim, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${r['label']}  ${r['n']}  (${(100 * (r['n'] as num) / (resTotal == 0 ? 1 : resTotal)).round()}%)', style: const TextStyle(color: Pal.mute, fontSize: 12.5)),
                ]),
              ),
          ]),
        ]),
      ),
      if (ratings.length == 6) ...[
        h('Ratings'),
        SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: i == 0 ? () => openScenes(context, title: 'Unrated', filters: {'flag': 'unrated'}) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('${ratings[i]}', style: const TextStyle(fontSize: 11.5, color: Pal.mute, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(height: 6 + 90 * ratings[i] / maxRating, decoration: BoxDecoration(color: i == 0 ? Pal.bg4 : null, gradient: i == 0 ? null : Pal.grad, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(height: 6),
                        Text(i == 0 ? '—' : '$i★', style: const TextStyle(fontSize: 12, color: Pal.dim)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
      if (byYear.isNotEmpty) ...[
        h('Scenes by release year'),
        columns(byYear, 'y', maxYear, onTap: (it) => openScenes(context, title: '${it['y']}', filters: {'year': it['y']})),
      ],
      if (byMonth.isNotEmpty) ...[
        h('Added per month'),
        columns(byMonth, 'm', maxMonth, short: true, h: 70, onTap: (it) => openScenes(context, title: 'Added ${it['m']}', filters: {'added': it['m']})),
      ],
      if (codecs.isNotEmpty) ...[
        h('Codecs'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Wrap(spacing: 8, runSpacing: 8, children: [for (final c in codecs) LChip('${c['label'].toString().toUpperCase()}  ${c['n']}')])),
      ],
      if (genders.isNotEmpty) ...[
        h('Performers by gender'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Wrap(spacing: 8, runSpacing: 8, children: [for (final g in genders) LChip('${g['label'].toString().toLowerCase().replaceAll('_', ' ')}  ${g['n']}')])),
      ],
      h('Top studios'),
      barList(_l('top_studios'), onTap: (it) => openScenes(context, title: it['name'].toString(), filters: {'studio': it['id']})),
      h('Top performers'),
      barList(_l('top_performers'), onTap: (it) => openPerformer(context, (it['id'] as num).toInt())),
      h('Top tags'),
      barList(_l('top_tags'), onTap: (it) => openScenes(context, title: '#${it['name']}', filters: {'tag': it['id']})),
    ]);
  }
}
