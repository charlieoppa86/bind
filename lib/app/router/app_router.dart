import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/enums.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_review_dialog.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/checkin/presentation/spot_select_screen.dart';
import '../../features/checkin/presentation/topic_examples_sheet.dart';
import '../../features/checkin/presentation/topic_setup_screen.dart';
import '../../features/guide/presentation/guide_screens.dart';
import '../../features/my/presentation/account_screen.dart';
import '../../features/my/presentation/blocked_users_screen.dart';
import '../../features/my/presentation/consent_history_screen.dart';
import '../../features/my/presentation/my_screen.dart';
import '../../features/my/presentation/plus_screen.dart';
import '../../features/my/presentation/profile_edit_screen.dart';
import '../../features/onboarding/presentation/consent_screen.dart';
import '../../features/onboarding/presentation/profile_setup_screen.dart';
import '../../features/requests/presentation/request_detail_screen.dart';
import '../../features/requests/presentation/requests_tabs.dart';
import '../../features/safety/presentation/block_confirm_dialog.dart';
import '../../features/safety/presentation/report_sheet.dart';
import '../../features/safety/presentation/safety_menu.dart';
import '../../features/safety/presentation/suspended_screen.dart';
import '../../features/session/session.dart';
import '../../features/spot/presentation/chat_request_sheet.dart';
import '../../features/spot/presentation/my_checkin_screen.dart';
import '../../features/spot/presentation/spot_feed_screen.dart';
import 'overlay_pages.dart';
import 'routes.dart';
import 'scaffold_with_nav_bar.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// 세션 상태에 따른 라우트 가드.
/// - 확인 중 → 스플래시 / 로그아웃 → 로그인 / 정지 → 정지 안내
/// - 온보딩 미완료 → 온보딩만 허용
/// - 체크인 전에는 스팟 탭 대신 체크인 흐름을 연다
String? sessionRedirect(Session session, String location) {
  bool at(String path) => location == path || location.startsWith('$path/');

  switch (session.status) {
    case SessionStatus.unknown:
      return location == Routes.splash ? null : Routes.splash;
    case SessionStatus.signedOut:
      return location == Routes.login ? null : Routes.login;
    case SessionStatus.suspended:
      return location == Routes.suspended ? null : Routes.suspended;
    case SessionStatus.needsOnboarding:
      return at(Routes.onboarding) ? null : Routes.onboardingProfile;
    case SessionStatus.ready:
      final home = session.isCheckedIn ? Routes.spot : Routes.checkinSpots;
      if (location == Routes.splash ||
          location == Routes.login ||
          location == Routes.suspended ||
          at(Routes.onboardingProfile) ||
          at(Routes.onboardingConsent)) {
        return home;
      }
      if (at(Routes.spot) && !session.isCheckedIn) return Routes.checkinSpots;
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        sessionRedirect(ref.read(sessionProvider), state.uri.path),
    routes: [
      // ── 인증 ──────────────────────────────────────────
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.onboarding,
        redirect: (_, state) => state.uri.path == Routes.onboarding
            ? Routes.onboardingProfile
            : null,
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, _) => const ProfileSetupScreen(),
          ),
          GoRoute(path: 'consent', builder: (_, _) => const ConsentScreen()),
          GoRoute(
            path: 'guide',
            builder: (_, _) => const OnboardingGuideScreen(),
          ),
        ],
      ),

      // ── 체크인 (셸 밖) ────────────────────────────────
      GoRoute(
        path: Routes.checkin,
        redirect: (_, state) =>
            state.uri.path == Routes.checkin ? Routes.checkinSpots : null,
        routes: [
          GoRoute(path: 'spots', builder: (_, _) => const SpotSelectScreen()),
          GoRoute(
            path: 'topic',
            builder: (_, state) => TopicSetupScreen(
              editId: state.uri.queryParameters['edit'],
              add: state.uri.queryParameters['add'] == '1',
            ),
            routes: [
              GoRoute(
                path: 'examples',
                pageBuilder: (_, state) => BottomSheetPage<String>(
                  key: state.pageKey,
                  child: TopicExamplesSheet(
                    category: TopicCategory.values
                        .where(
                          (c) =>
                              c.name == state.uri.queryParameters['category'],
                        )
                        .firstOrNull,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── 하단 탭 셸 ────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ScaffoldWithNavBar(navigationShell: shell),
        branches: [
          // 탭 1: 스팟
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.spot,
                builder: (_, _) => const SpotFeedScreen(),
                routes: [
                  GoRoute(
                    path: 'request/:userId',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (_, state) => BottomSheetPage<String>(
                      key: state.pageKey,
                      child: ChatRequestSheet(
                        userId: state.pathParameters['userId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'me',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const MyCheckinScreen(),
                  ),
                ],
              ),
            ],
          ),
          // 탭 2: 요청함
          StatefulShellBranch(
            initialLocation: Routes.requestsReceived,
            routes: [
              GoRoute(
                path: Routes.requests,
                redirect: (_, state) => state.uri.path == Routes.requests
                    ? Routes.requestsReceived
                    : null,
                routes: [
                  GoRoute(
                    path: 'received',
                    builder: (_, _) => const ReceivedRequestsScreen(),
                    routes: [
                      GoRoute(
                        path: ':requestId',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => RequestDetailScreen(
                          requestId: state.pathParameters['requestId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'sent',
                    builder: (_, _) => const SentRequestsScreen(),
                  ),
                ],
              ),
            ],
          ),
          // 탭 3: 채팅
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chats,
                builder: (_, _) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: ':chatId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) =>
                        ChatRoomScreen(chatId: state.pathParameters['chatId']!),
                    routes: [
                      GoRoute(
                        path: 'review',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (_, state) => DialogPage<void>(
                          key: state.pageKey,
                          child: ChatReviewDialog(
                            chatId: state.pathParameters['chatId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 탭 4: 마이
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.my,
                builder: (_, _) => const MyScreen(),
                routes: [
                  for (final (path, screen) in const <(String, Widget)>[
                    ('profile', ProfileEditScreen()),
                    ('plus', PlusScreen()),
                    ('blocked', BlockedUsersScreen()),
                    ('consent', ConsentHistoryScreen()),
                    ('guide', MyGuideScreen()),
                    ('account', AccountScreen()),
                  ])
                    GoRoute(
                      path: path,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, _) => screen,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── 글로벌 ────────────────────────────────────────
      GoRoute(
        path: '/report/:targetId',
        pageBuilder: (_, state) => BottomSheetPage<ReportOutcome>(
          key: state.pageKey,
          child: ReportSheet(
            targetId: state.pathParameters['targetId']!,
            source: ReportSource.values
                .where((s) => s.name == state.uri.queryParameters['source'])
                .firstOrNull,
          ),
        ),
      ),
      GoRoute(
        path: '/block/:targetId',
        pageBuilder: (_, state) => DialogPage<bool>(
          key: state.pageKey,
          child: BlockConfirmDialog(
            targetId: state.pathParameters['targetId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.suspended,
        builder: (_, _) => const SuspendedScreen(),
      ),
    ],
  );
});
