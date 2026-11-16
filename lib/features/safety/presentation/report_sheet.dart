import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import 'safety_menu.dart';

/// 글로벌 > 신고 (바텀시트, US-010).
/// 스팟 피드·요청 상세·대화방 3곳에서 호출한다.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({required this.targetId, this.source, super.key});

  final String targetId;
  final ReportSource? source;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportReason? _reason;
  bool _alsoBlock = true;

  void _submit() {
    // TODO(firebase): reports 문서 생성 (+ users/{me}/blocks)
    ref
        .read(demoStoreProvider.notifier)
        .report(widget.targetId, _reason!, alsoBlock: _alsoBlock);
    context.pop(ReportOutcome(blocked: _alsoBlock));
  }

  @override
  Widget build(BuildContext context) {
    final nickname =
        ref.watch(userProvider(widget.targetId).select((u) => u?.nickname)) ??
        '상대';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page - 4,
          0,
          AppSpacing.page - 4,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$nickname님을 신고할까요?', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '신고한 사람은 상대에게 알려지지 않아요. '
              '서로 다른 ${AppLimits.reportsUntilSuspension}명에게 신고되면 이용이 정지돼요.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final r in ReportReason.values)
              Pressable(
                onTap: () => setState(() => _reason = r),
                borderRadius: AppRadius.card,
                color: _reason == r
                    ? AppColors.primarySoft
                    : Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.label,
                          style: AppTypography.bodyLarge.copyWith(
                            color: _reason == r
                                ? AppColors.primary
                                : AppColors.heading,
                            fontWeight: _reason == r
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (_reason == r)
                        const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            CheckboxListTile(
              value: _alsoBlock,
              onChanged: (v) => setState(() => _alsoBlock = v ?? false),
              title: const Text('이 사용자 차단하기', style: AppTypography.body),
              subtitle: const Text(
                '카드·요청·대화가 더 이상 보이지 않아요',
                style: AppTypography.caption,
              ),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _reason == null ? null : _submit,
              child: const Text('신고하기'),
            ),
          ],
        ),
      ),
    );
  }
}
