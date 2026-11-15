import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/notice/notice_banner.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BindApp extends ConsumerWidget {
  const BindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'BIND',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // 신청 도착·수락·만료·체류 종료 등 앱 안 알림.
      // TODO(fcm): 앱이 닫혀 있을 때는 FCM 푸시 → 같은 경로로 딥링크
      builder: (context, child) => AnnotatedRegion(
        value: AppTheme.systemOverlay,
        child: NoticeBannerHost(onOpen: router.go, child: child!),
      ),
    );
  }
}
