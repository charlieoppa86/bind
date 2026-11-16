import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import 'profile_form.dart';
import '../../session/account_controller.dart';

/// 인증 > 온보딩 > 프로필 설정 (US-002)
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 처음 그릴 때 임시값만 채우면 되므로 read로 읽는다(입력 중 다시 그리지 않음).
    final (draftNickname, draftJobTag, draftJobCustom) = ref.read(
      draftProfileProvider,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '가입 취소',
          // US-001: 가입 도중 취소하면 첫 화면으로, 정보는 남기지 않는다.
          onPressed: () => ref.read(accountProvider).signOut(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ProfileForm(
          header: const OnboardingStep(
            step: 1,
            total: 2,
            title: '닉네임을 설정하세요',
            description: '실명이나 사진 없이, 닉네임과 하는 일만 상대에게 보여요.',
          ),
          initialNickname: draftNickname ?? '',
          initialJobTag: draftJobTag,
          initialJobCustom: draftJobCustom,
          submitLabel: '다음',
          onSubmit: (nickname, jobTag, jobCustom) {
            ref
                .read(demoStoreProvider.notifier)
                .saveDraftProfile(nickname, jobTag, jobCustom: jobCustom);
            context.push(Routes.onboardingConsent);
          },
        ),
      ),
    );
  }
}
