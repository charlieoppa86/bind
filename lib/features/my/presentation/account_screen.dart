import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/demo/demo_store.dart';

/// 마이 > 마이 > 계정
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirm(
      context,
      title: '정말 탈퇴할까요?',
      message:
          '프로필과 체크인 기록이 삭제돼요. 대화 상대에게는 “떠난 사용자”로 보이고, '
          '더 이상 메시지를 주고받을 수 없어요.',
      confirmLabel: '탈퇴',
      destructive: true,
    );
    if (ok != true) return;
    // TODO(firebase): Functions로 계정 삭제
    ref.read(demoStoreProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(demoStoreProvider).me;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: AppColors.groupedBackground,
        title: const Text('계정'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        children: [
          SectionCard(
            child: Row(
              children: [
                IconTile(isIos ? Icons.apple : Icons.account_circle_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIos ? 'Google 또는 Apple 계정' : 'Google 계정',
                        style: AppTypography.subtitle,
                      ),
                      Text(
                        '${me?.nickname ?? ''}(으)로 로그인됨',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                ListRow(
                  title: '로그아웃',
                  onTap: () => ref.read(demoStoreProvider.notifier).signOut(),
                ),
                ListRow(
                  title: '탈퇴하기',
                  titleStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.secondary,
                  ),
                  onTap: () => _delete(context, ref),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SectionLabel('개발용 (데모 모드)'),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: ListRow(
                title: '이용 정지 화면 미리보기',
                subtitle: '로그아웃하면 원래대로 돌아와요',
                onTap: () =>
                    ref.read(demoStoreProvider.notifier).previewSuspension(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
