import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import 'usage_guide_view.dart';
import '../../session/account_controller.dart';

/// 인증 > 온보딩 > 사용법 가이드 (가입 직후 1회)
class OnboardingGuideScreen extends ConsumerWidget {
  const OnboardingGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: UsageGuideView(
        onDone: () {
          ref.read(accountProvider).markGuideSeen();
          context.go(Routes.checkinSpots);
        },
      ),
    );
  }
}

/// 마이 > 마이 > 사용법 가이드 (다시 보기)
class MyGuideScreen extends StatelessWidget {
  const MyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용법 가이드')),
      body: UsageGuideView(onDone: () => context.pop(), showSkip: false),
    );
  }
}
