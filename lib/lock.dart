import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

final LocalAuthentication _auth = LocalAuthentication();

/// Can this phone authenticate at all (fingerprint, face, or screen lock PIN/pattern)?
Future<bool> lockSupported() async {
  try {
    return await _auth.isDeviceSupported();
  } catch (_) {
    return false;
  }
}

/// Shows the system prompt (biometrics, with the phone's PIN/pattern as fallback).
Future<bool> authenticate(String reason) async {
  try {
    return await _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}

/// Sits above the whole app (including pushed screens such as the player).
/// Locks on a cold start and after the app has been in the background for the chosen time,
/// and hides the content whenever the app is not in the foreground (app switcher privacy).
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = true;
  bool _decided = false; // cold-start decision made once settings are loaded
  bool _covered = false;
  bool _authing = false;
  DateTime? _left;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final app = context.read<AppState>();
    if (s == AppLifecycleState.resumed) {
      if (app.lockEnabled && _left != null && DateTime.now().difference(_left!).inSeconds >= app.lockAfter) {
        _locked = true;
      }
      _left = null;
      setState(() => _covered = false);
      if (_locked && app.lockEnabled) _prompt();
    } else {
      // inactive also fires while the system biometric sheet is open, so only paused/hidden start the timer
      if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) _left ??= DateTime.now();
      if (!_authing) setState(() => _covered = true);
    }
  }

  Future<void> _prompt() async {
    if (_authing) return;
    _authing = true;
    final ok = await authenticate('Unlock Stash Lens');
    _authing = false;
    if (!mounted) return;
    setState(() {
      if (ok) _locked = false;
      _covered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loaded && !_decided) {
      _decided = true;
      _locked = app.lockEnabled;
      if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
    }
    if (!app.lockEnabled && _locked && _decided) _locked = false;
    final hide = app.loaded && (_locked || _covered) && app.lockEnabled;
    return Stack(children: [
      widget.child,
      if (hide)
        Positioned.fill(
          child: Material(
            color: Pal.bg,
            child: Center(
              child: _locked
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      const BrandMark(size: 64),
                      const SizedBox(height: 22),
                      Text('Stash Lens is locked', style: heading(22)),
                      const SizedBox(height: 22),
                      GradButton(label: 'Unlock', icon: Icons.fingerprint_rounded, onTap: _prompt),
                    ])
                  : const BrandMark(size: 64),
            ),
          ),
        ),
    ]);
  }
}
