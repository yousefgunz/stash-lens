import 'package:flutter/material.dart';

import 'feed_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'performers_screen.dart';
import 'scenes_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _visited = <int>{0};

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const HomeScreen();
      case 1:
        return FeedScreen(active: _tab == 1);
      case 2:
        return const SafeArea(bottom: false, child: SceneBrowser(title: 'Scenes'));
      case 3:
        return const PerformersScreen();
      default:
        return const MoreScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: List.generate(5, (i) => _visited.contains(i) ? _page(i) : const SizedBox.shrink()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_rounded), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie_rounded), label: 'Scenes'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Performers'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }
}
