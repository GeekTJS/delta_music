import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/discovery/discovery_page.dart';
import '../pages/home/home_page.dart';
import '../pages/library/library_page.dart';
import '../pages/player/player_page.dart';
import '../pages/home/playlist_detail_page.dart';
import '../pages/search/search_page.dart';
import '../pages/settings/settings_page.dart';

enum _ShellTab {
  home(0, '首页', Icons.home_outlined, Icons.home),
  discovery(1, '发现', Icons.explore_outlined, Icons.explore),
  library(2, '音乐库', Icons.library_music_outlined, Icons.library_music);

  final int index;
  final String label;
  final IconData unselectedIcon;
  final IconData selectedIcon;

  const _ShellTab(
    this.index,
    this.label,
    this.unselectedIcon,
    this.selectedIcon,
  );
}

class _ShellScaffold extends StatelessWidget {
  final Widget child;

  const _ShellScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    final currentIndex = switch (location) {
      '/' => 0,
      '/discovery' => 1,
      '/library' => 2,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          final tab = _ShellTab.values[index];
          context.go(tab == _ShellTab.home ? '/' : '/${tab.name}');
        },
        items: _ShellTab.values
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.unselectedIcon),
                activeIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomePage(),
          ),
        ),
        GoRoute(
          path: '/discovery',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DiscoveryPage(),
          ),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LibraryPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/playlist/:id',
      builder: (context, state) => PlaylistDetailPage(
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/player',
      pageBuilder: (context, state) => MaterialPage<void>(
        fullscreenDialog: true,
        child: const PlayerPage(),
      ),
    ),
  ],
);