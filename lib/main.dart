import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/setup_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Pal.surface,
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
      home: Consumer<AppState>(
        builder: (_, s, __) {
          if (!s.loaded) return const Scaffold(body: Center(child: LensMark()));
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: s.client == null ? const SetupScreen(key: ValueKey('setup')) : const Shell(key: ValueKey('shell')),
          );
        },
      ),
    );
  }
}
