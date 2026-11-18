import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _url;
  late final TextEditingController _pw;
  bool _busy = false;
  bool _showPw = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _url = TextEditingController(text: s.savedUrl.isEmpty ? 'http://10.0.0.64:8765' : s.savedUrl);
    _pw = TextEditingController(text: s.savedPassword);
  }

  @override
  void dispose() {
    _url.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().connect(_url.text, _pw.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: -140,
          right: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFFFF4757).withOpacity(0.28), Colors.transparent])),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const BrandMark(size: 52).animate().scale(begin: const Offset(0.6, 0.6), duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
                  const SizedBox(height: 26),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Stash', style: heading(58)),
                    GradText('Lens', heading(58)),
                  ]).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
                  const SizedBox(height: 12),
                  const Text(
                    'Connect to the Stash Lens server running on your computer. Your phone needs to reach it: same Wi-Fi, or through a VPN.',
                    style: TextStyle(color: Pal.mute, height: 1.45, fontSize: 15),
                  ).animate().fadeIn(delay: 260.ms),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Stash Lens address', hintText: 'http://192.168.1.20:8765'),
                  ).animate().fadeIn(delay: 360.ms),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pw,
                    obscureText: !_showPw,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Access password (if you set one)',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showPw = !_showPw),
                        icon: Icon(_showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Pal.dim),
                      ),
                    ),
                    onSubmitted: (_) => _connect(),
                  ).animate().fadeIn(delay: 440.ms),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: Pal.a, height: 1.35)),
                  ],
                  const SizedBox(height: 22),
                  GradButton(label: _busy ? 'Connecting…' : 'Connect', onTap: _busy ? null : _connect, expand: true, height: 54).animate().fadeIn(delay: 520.ms),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Pal.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
                    child: const Text(
                      'On the computer running Stash Lens: Settings → Network access → switch on “Allow other computers on my network” '
                      '(and set an access password). The address is shown there.',
                      style: TextStyle(color: Pal.mute, fontSize: 13, height: 1.45),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
