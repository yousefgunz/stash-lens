import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _url;
  late final TextEditingController _key;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _url = TextEditingController(text: s.savedUrl.isEmpty ? 'http://10.0.0.64:9999' : s.savedUrl);
    _key = TextEditingController(text: s.savedKey);
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().connect(_url.text, _key.text);
      widget.onDone?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LensMark(size: 64).animate().rotate(begin: -0.15, duration: 900.ms, curve: Curves.easeOutCubic).fadeIn(),
                const SizedBox(height: 28),
                Text('Stash\nLens', style: display(64)).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                const Text(
                  'Point the app at your Stash server. Your phone needs to reach it — same Wi-Fi, or through your VPN.',
                  style: TextStyle(color: Pal.dim, height: 1.45),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 32),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Server address'),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 14),
                TextField(
                  controller: _key,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'API key (Settings → Security in Stash)'),
                ).animate().fadeIn(delay: 480.ms),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: Pal.ember)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _connect,
                    style: FilledButton.styleFrom(
                      backgroundColor: Pal.ember,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                        : const Text('Connect', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ).animate().fadeIn(delay: 560.ms),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
