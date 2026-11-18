import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/links/app_links.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../session/account_controller.dart';

/// 글로벌 > 이용 정지 안내. 뒤로가기 불가, 로그아웃만 허용.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.block,
                        size: 40,
                        color: AppColors.heading,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text('이용이 정지되었어요', style: AppTypography.heading),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        '서로 다른 사용자 ${AppLimits.reportsUntilSuspension}명에게 '
                        '신고가 누적되었거나 이용 규칙을 크게 어겨 '
                        'BIND 이용이 정지되었습니다.',
                        style: AppTypography.body,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '정지 기간에는 체크인, 대화 요청, 채팅을 이용할 수 없어요. '
                              '정지에 이의가 있다면 아래 이메일로 보내 주세요. '
                              '${AppLimits.appealReview.inDays}일 안에 검토 결과를 알려 드려요.',
                              style: AppTypography.body,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const SelectableText(
                              AppLinks.supportEmail,
                              style: AppTypography.supportingTitle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => openLink(
                          ref,
                          AppLinks.supportMail(subject: '[BIND] 이용 정지 이의 제기'),
                        ),
                        child: const Text('이의 제기 메일 보내기'),
                      ),
                    ],
                  ),
                ),
              ),
              BottomCta(
                child: OutlinedButton(
                  onPressed: () => ref.read(accountProvider).signOut(),
                  child: const Text('로그아웃'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
