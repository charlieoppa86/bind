import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../data/demo/demo_store.dart';
import 'profile_form.dart';

/// 인증 > 온보딩 > 프로필 설정 (US-002)
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '가입 취소',
          // US-001: 가입 도중 취소하면 첫 화면으로, 정보는 남기지 않는다.
          onPressed: () => ref.read(demoStoreProvider.notifier).signOut(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ProfileForm(
          header: const OnboardingStep(
            step: 1,
            total: 2,
            title: '어떻게 불러드릴까요?',
            description: '실명이나 사진 없이, 닉네임과 하는 일만 상대에게 보여요.',
          ),
          initialNickname: db.draftNickname ?? '',
          initialJobTag: db.draftJobTag,
          submitLabel: '다음',
          onSubmit: (nickname, jobTag) {
            ref
                .read(demoStoreProvider.notifier)
                .saveDraftProfile(nickname, jobTag);
            context.push(Routes.onboardingConsent);
          },
        ),
      ),
    );
  }
}
