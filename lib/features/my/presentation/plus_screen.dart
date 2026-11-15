import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/demo/demo_store.dart';

/// 마이 > 마이 > BIND+ (US-019)
class PlusScreen extends ConsumerWidget {
  const PlusScreen({super.key});

  static final _won = NumberFormat.decimalPattern('ko');

  Future<void> _subscribe(BuildContext context, WidgetRef ref) async {
    final price = _won.format(AppLimits.plusMonthlyPriceWon);
    final ok = await showConfirm(
      context,
      title: '월 $price원으로 BIND+를 시작할까요?',
      message: '언제든 해지할 수 있고, 해지해도 결제한 기간까지는 혜택이 유지돼요.\n(데모 모드라 실제 결제는 되지 않아요)',
      confirmLabel: '결제하기',
    );
    if (ok != true || !context.mounted) return;
    // TODO(billing): in_app_purchase 구독 결제
    ref.read(demoStoreProvider.notifier).subscribePlus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('BIND+가 시작됐어요. 혜택이 바로 적용돼요.')));
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    DateTime until,
  ) async {
    final ok = await showConfirm(
      context,
      title: '구독을 해지할까요?',
      message: '${TimeFormat.fullDate(until)}까지는 혜택이 그대로 유지되고, 그 뒤로 결제되지 않아요.',
      cancelLabel: '유지하기',
      confirmLabel: '해지',
    );
    if (ok != true) return;
    ref.read(demoStoreProvider.notifier).cancelPlus();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final active = db.isPlusActive;
    final until = db.me?.plusExpiresAt;
    final price = _won.format(AppLimits.plusMonthlyPriceWon);

    return Scaffold(
      appBar: AppBar(title: const Text('BIND+')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  active ? 'BIND+ 이용 중이에요' : '더 많은 대화를 열어두세요',
                  style: AppTypography.heading,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  active
                      ? (db.plusAutoRenew
                            ? '${TimeFormat.fullDate(until!)}에 자동 갱신돼요'
                            : '해지했어요. ${TimeFormat.fullDate(until!)}까지 혜택이 유지돼요')
                      : '월 $price원',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _Compare(
                  icon: Icons.short_text_rounded,
                  title: '동시에 올리는 주제',
                  free: '${AppLimits.freeActiveTopics}개',
                  plus: '${AppLimits.plusActiveTopics}개',
                ),
                _Compare(
                  icon: Icons.send_outlined,
                  title: '하루 대화 신청',
                  free: '${AppLimits.freeDailyRequests}번',
                  plus: '무제한',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '개발 질문과 이직 고민처럼 서로 다른 대화를 한 번에 열어둘 수 있어요.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          BottomCta(
            child: active
                ? (db.plusAutoRenew
                      ? OutlinedButton(
                          onPressed: () => _cancel(context, ref, until!),
                          child: const Text('구독 해지'),
                        )
                      : FilledButton(
                          onPressed: () => ref
                              .read(demoStoreProvider.notifier)
                              .subscribePlus(),
                          child: const Text('다시 구독하기'),
                        ))
                : FilledButton(
                    onPressed: () => _subscribe(context, ref),
                    child: Text('월 $price원으로 시작하기'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare({
    required this.icon,
    required this.title,
    required this.free,
    required this.plus,
  });

  final IconData icon;
  final String title;
  final String free;
  final String plus;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.heading),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: AppTypography.supportingTitle)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('무료 $free', style: AppTypography.caption),
              const SizedBox(height: 2),
              StatusPill('BIND+ $plus', tone: PillTone.active),
            ],
          ),
        ],
      ),
    );
  }
}
