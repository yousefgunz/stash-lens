import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../lock.dart';
import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'browse_screen.dart';
import 'stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final st = app.status;
    final counts = (st['counts'] as Map?)?.cast<String, dynamic>() ?? {};

    Widget tile(IconData i, String t, String sub, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.line)),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(gradient: Pal.grad, borderRadius: BorderRadius.circular(12)), child: Icon(i, color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Pal.mute, fontSize: 12.5)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Pal.dim),
            ]),
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 90), children: [
        Row(children: [
          Expanded(child: Text('More', style: heading(34))),
          IconButton(onPressed: () => openSearch(context), icon: const Icon(Icons.search_rounded)),
        ]),
        const SizedBox(height: 14),
        tile(Icons.grid_view_rounded, 'Studios & tags', 'Browse the library by studio or tag', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Scaffold(body: BrowseScreen())))),
        tile(Icons.insights_rounded, 'Library', 'Statistics, resolutions, years, top lists', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen()))),
        tile(Icons.health_and_safety_rounded, 'Library health', 'Missing metadata, duplicates, files not found', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen()))),
        tile(Icons.history_rounded, 'In progress', 'Scenes you started and haven\'t finished', () => openScenes(context, title: 'In progress', filters: {'flag': 'resumable'}, sort: 'last_played')),
        tile(Icons.favorite_rounded, 'From your favourites', 'New scenes from favourite performers and studios', () => openScenes(context, title: 'Favourites', filters: {'flag': 'favorites'})),
        const SizedBox(height: 18),
        Text('Server', style: heading(20)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Connected to', style: TextStyle(color: Pal.dim, fontSize: 12)),
            const SizedBox(height: 2),
            Text(app.savedUrl, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            if (counts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${fmtNum(counts['scenes'] ?? 0)} scenes  ·  ${fmtNum(counts['performers'] ?? 0)} performers  ·  ${fmtNum(counts['studios'] ?? 0)} studios', style: const TextStyle(color: Pal.mute, fontSize: 13)),
            ],
            if (st['schema_version'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Stash database schema ${st['schema_version']}${st['sync'] == true ? '  ·  sync with Stash on' : ''}', style: const TextStyle(color: Pal.dim, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.line)),
          child: SwitchListTile(
            value: app.autoplayNext,
            onChanged: app.setAutoplay,
            activeColor: Pal.a,
            title: const Text('Autoplay next', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Continue with a related scene when one ends', style: TextStyle(color: Pal.mute, fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.line)),
          child: Column(children: [
            SwitchListTile(
              value: app.lockEnabled,
              onChanged: (v) async {
                final st = context.read<AppState>();
                final messenger = ScaffoldMessenger.of(context);
                if (!v) {
                  if (await authenticate('Turn off the app lock')) st.setLock(false);
                  return;
                }
                if (!await lockSupported()) {
                  messenger.showSnackBar(const SnackBar(content: Text('Set a fingerprint, face or screen lock in your phone settings first.')));
                  return;
                }
                if (await authenticate('Turn on the app lock')) st.setLock(true);
              },
              activeColor: Pal.a,
              title: const Text('App lock', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Fingerprint, Face ID or your phone PIN to open the app', style: TextStyle(color: Pal.mute, fontSize: 12.5)),
            ),
            if (app.lockEnabled)
              ListTile(
                title: const Text('Lock after leaving the app', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: DropdownButton<int>(
                  value: const [0, 60, 300].contains(app.lockAfter) ? app.lockAfter : 0,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Pal.bg3,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Immediately')),
                    DropdownMenuItem(value: 60, child: Text('1 minute')),
                    DropdownMenuItem(value: 300, child: Text('5 minutes')),
                  ],
                  onChanged: (v) => context.read<AppState>().setLockAfter(v ?? 0),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GhostButton(
              label: 'Clear cache',
              icon: Icons.cleaning_services_rounded,
              onTap: () {
                apiOf(context).clearCache();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared. Pull down on any screen to reload.')));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: GhostButton(label: 'Change server', icon: Icons.swap_horiz_rounded, onTap: () => context.read<AppState>().disconnect())),
        ]),
        const SizedBox(height: 22),
        const Center(child: Text('Stash Lens for mobile · read-only view of your Stash library', style: TextStyle(color: Pal.dim, fontSize: 12))),
      ]),
    );
  }
}

// ───────────────────────────── health ─────────────────────────────

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await apiOf(context).health();
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((_d?['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final total = (_d?['total'] as num?) ?? 0;
    Color sev(String s) => s == 'bad' ? Pal.a : (s == 'warn' ? Pal.a2 : Pal.mute);
    return Scaffold(
      appBar: AppBar(title: Text('Library health', style: heading(24))),
      body: _error != null
          ? ErrorNote(_error!, onRetry: () {
              setState(() => _error = null);
              _load();
            })
          : _d == null
              ? const Spin()
              : ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 40), children: [
                  Text('${fmtNum(total)} scenes checked', style: const TextStyle(color: Pal.mute)),
                  const SizedBox(height: 14),
                  for (final it in items)
                    Builder(builder: (context) {
                      final n = (it['n'] as num).toInt();
                      final flag = it['flag']?.toString();
                      final ok = n == 0;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: (flag != null && n > 0) ? () => openScenes(context, title: it['label'].toString(), filters: {'flag': flag}) : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
                          child: Row(children: [
                            Container(
                              width: 56,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: (ok ? const Color(0xFF3DDC84) : sev(it['sev'].toString())).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: ok ? const Icon(Icons.check_rounded, color: Color(0xFF3DDC84)) : Text(fmtNum(n), style: TextStyle(fontWeight: FontWeight.w900, color: sev(it['sev'].toString()))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it['label'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(it['desc'].toString(), style: const TextStyle(color: Pal.mute, fontSize: 12.5)),
                            ])),
                            if (flag != null && n > 0) const Icon(Icons.chevron_right_rounded, color: Pal.dim),
                          ]),
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  Text('Deeper checks', style: heading(19)),
                  const SizedBox(height: 12),
                  GhostButton(label: 'Find duplicate files', icon: Icons.content_copy_rounded, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _DupesScreen()))),
                  const SizedBox(height: 10),
                  GhostButton(label: 'Check files exist on the computer', icon: Icons.find_in_page_rounded, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _MissingScreen()))),
                ]),
    );
  }
}

class _DupesScreen extends StatefulWidget {
  const _DupesScreen();
  @override
  State<_DupesScreen> createState() => _DupesScreenState();
}

class _DupesScreenState extends State<_DupesScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  @override
  void initState() {
    super.initState();
    apiOf(context).duplicates().then((d) {
      if (mounted) setState(() => _d = d);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = ((_d?['groups'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text('Duplicates', style: heading(24))),
      body: _error != null
          ? ErrorNote(_error!)
          : _d == null
              ? const Spin()
              : groups.isEmpty
                  ? Center(child: Text(_d!['note']?.toString() ?? 'No duplicate files found.', style: const TextStyle(color: Pal.mute)))
                  : ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 40), children: [
                      for (final g in groups)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${g['type']}'.toUpperCase() + (g['type'] == 'phash' ? '  ·  visually similar' : '  ·  identical file'), style: const TextStyle(color: Pal.a2, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            for (final s in (g['scenes'] as List).cast<Map<String, dynamic>>())
                              InkWell(
                                onTap: () => openSceneId(context, (s['id'] as num).toInt()),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${s['path']}  ·  ${fmtSize((s['size'] as num?) ?? 0)}', style: const TextStyle(color: Pal.dim, fontSize: 11.5)),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                    ]),
    );
  }
}

class _MissingScreen extends StatefulWidget {
  const _MissingScreen();
  @override
  State<_MissingScreen> createState() => _MissingScreenState();
}

class _MissingScreenState extends State<_MissingScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  @override
  void initState() {
    super.initState();
    apiOf(context).missing().then((d) {
      if (mounted) setState(() => _d = d);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final miss = ((_d?['missing'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text('Missing files', style: heading(24))),
      body: _error != null
          ? ErrorNote(_error!)
          : _d == null
              ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Spin(), SizedBox(height: 16), Center(child: Text('Checking every file… this can take a while.', style: TextStyle(color: Pal.mute)))])
              : ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 40), children: [
                  Text('${fmtNum(_d!['checked'])} checked  ·  ${fmtNum(_d!['missing_count'])} missing${_d!['complete'] == false ? '  ·  stopped early' : ''}', style: const TextStyle(color: Pal.mute)),
                  if (_d!['all_missing_hint'] == true)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Pal.a.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Every file looks missing: the library probably lives on another machine, so these paths don\'t exist where Stash Lens runs. That is normal then.', style: TextStyle(height: 1.4)),
                    ),
                  const SizedBox(height: 14),
                  for (final m in miss)
                    InkWell(
                      onTap: () => openSceneId(context, (m['id'] as num).toInt()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(m['path'].toString(), style: const TextStyle(color: Pal.dim, fontSize: 11.5)),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}
