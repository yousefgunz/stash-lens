import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/performer_screen.dart';
import 'screens/player_screen.dart';
import 'screens/scene_screen.dart';
import 'screens/scenes_screen.dart';
import 'screens/search_screen.dart';

Future<void> openScene(BuildContext context, Scene s) {
  return Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => SceneScreen(preview: s),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

void openSceneId(BuildContext context, int id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SceneScreen(sceneId: id)));
}

Future<void> openPerformer(BuildContext context, int id) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => PerformerScreen(id: id)));
}

/// A standalone scene list with fixed filters (studio, tag, flag, year …) and a back button.
void openScenes(BuildContext context, {String? title, Map<String, dynamic> filters = const {}, String? sort}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: SceneBrowser(title: title ?? 'Scenes', fixed: filters, initialSort: sort, showBack: true),
      ),
    ),
  ));
}

void openSearch(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SearchScreen(),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Opens the player straight away. [startAt] seconds overrides the saved resume point.
void playScene(BuildContext context, Scene s, {double? startAt, int? fileId, List<Scene> queue = const []}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerScreen(scene: s, startAt: startAt, fileId: fileId, queue: queue),
  ));
}
