import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'lock.dart';
import 'screens/setup_screen.dart';
import 'screens/shell.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF090A0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(ChangeNotifierProvider(create: (_) => AppState()..load(), child: const LensApp()));
}

class LensApp extends StatelessWidget {
  const LensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stash Lens',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
      home: Consumer<AppState>(
        builder: (_, s, __) {
          if (!s.loaded) return const Scaffold(body: Center(child: BrandMark(size: 56)));
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            child: s.api == null ? const SetupScreen(key: ValueKey('setup')) : const Shell(key: ValueKey('shell')),
          );
        },
      ),
    );
  }
}
