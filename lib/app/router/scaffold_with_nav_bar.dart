import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/demo/demo_providers.dart';

/// 하단 탭 4개: 체크인 · 채팅 · 요청함 · 마이페이지
/// (순서는 app_router.dart의 StatefulShellBranch 순서와 같아야 한다)
///
/// 셸은 아무것도 구독하지 않는다. 숫자 배지만 각자 자기 숫자를 구독해서
/// 요청·메시지가 와도 배지 아이콘만 다시 그린다.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place),
              label: '체크인',
            ),
            NavigationDestination(
              icon: _UnreadBadge(Icons.chat_bubble_outline),
              selectedIcon: _UnreadBadge(Icons.chat_bubble),
              label: '채팅',
            ),
            NavigationDestination(
              icon: _RequestsBadge(Icons.inbox_outlined),
              selectedIcon: _RequestsBadge(Icons.inbox),
              label: '요청함',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이페이지',
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsBadge extends ConsumerWidget {
  const _RequestsBadge(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CountBadgeIcon(
    count: ref.watch(pendingReceivedCountProvider),
    icon: icon,
  );
}

class _UnreadBadge extends ConsumerWidget {
  const _UnreadBadge(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _CountBadgeIcon(count: ref.watch(unreadTotalProvider), icon: icon);
}

class _CountBadgeIcon extends StatelessWidget {
  const _CountBadgeIcon({required this.count, required this.icon});

  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    child: Icon(icon),
  );
}
