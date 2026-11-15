import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/demo/demo_store.dart';

/// 하단 탭 4개: 스팟 · 신청함 · 채팅 · 마이
class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final pending = db.pendingReceivedCount;
    final unread = db.unreadTotal(DateTime.now());

    Widget badge(int count, Widget icon) =>
        Badge(isLabelVisible: count > 0, label: Text('$count'), child: icon);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place),
              label: '스팟',
            ),
            NavigationDestination(
              icon: badge(pending, const Icon(Icons.inbox_outlined)),
              selectedIcon: badge(pending, const Icon(Icons.inbox)),
              label: '신청함',
            ),
            NavigationDestination(
              icon: badge(unread, const Icon(Icons.chat_bubble_outline)),
              selectedIcon: badge(unread, const Icon(Icons.chat_bubble)),
              label: '채팅',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
