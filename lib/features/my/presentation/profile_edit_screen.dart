import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/demo/demo_store.dart';
import '../../onboarding/presentation/profile_form.dart';

/// 마이 > 마이 > 프로필 수정 (규칙은 온보딩과 동일)
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(demoStoreProvider).me;
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 수정')),
      body: SafeArea(
        top: false,
        child: ProfileForm(
          initialNickname: me?.nickname ?? '',
          initialJobTag: me?.jobTag,
          initialJobCustom: me?.jobCustom,
          submitLabel: '저장',
          onSubmit: (nickname, jobTag, jobCustom) {
            // TODO(firebase): users/{uid} 갱신
            ref
                .read(demoStoreProvider.notifier)
                .updateProfile(nickname, jobTag, jobCustom: jobCustom);
            context.pop();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('프로필을 저장했어요')));
          },
        ),
      ),
    );
  }
}
