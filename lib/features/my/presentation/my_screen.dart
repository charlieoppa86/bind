import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';

/// 마이 > 마이
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final me = db.me;
    final now = DateTime.now();
    final mine = db.myCheckins(now);
    if (me == null) return const Scaffold();
    final toBadge = AppLimits.trustBadgeThreshold - me.goodReviewCount;

    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: AppColors.groupedBackground,
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        title: const Text('마이', style: AppTypography.title),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          // 프로필
          SectionCard(
            onTap: () => context.push(Routes.myProfile),
            child: Column(
              children: [
                Row(
                  children: [
                    InitialAvatar(me.nickname, size: 56),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  me.nickname,
                                  style: AppTypography.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (me.hasTrustBadge) ...[
                                const SizedBox(width: AppSpacing.sm),
                                const TrustBadge(),
                              ],
                            ],
                          ),
                          Text(
                            '${me.jobTag.label} · 프로필 수정',
                            style: AppTypography.body.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.tertiary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      _Stat(label: '받은 좋았어요', value: '${me.goodReviewCount}'),
                      _divider(),
                      _Stat(
                        label: '진행 중 대화',
                        value: '${db.visibleChats(now).length}',
                      ),
                      _divider(),
                      _Stat(label: '오늘 보낸 신청', value: '${db.sentToday(now)}'),
                    ],
                  ),
                ),
                if (!me.hasTrustBadge) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '“좋았어요” $toBadge번 더 받으면 카드에 신뢰 표시가 붙어요',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // BIND+
          SectionCard(
            onTap: () => context.push(Routes.myPlus),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                IconTile(
                  Icons.bolt_rounded,
                  color: AppColors.primarySoft,
                  iconColor: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        db.isPlusActive ? 'BIND+ 이용 중' : 'BIND+ 시작하기',
                        style: AppTypography.subtitle,
                      ),
                      Text(
                        db.isPlusActive
                            ? (db.plusAutoRenew
                                  ? '${TimeFormat.date(me.plusExpiresAt!)}에 자동 갱신'
                                  : '${TimeFormat.date(me.plusExpiresAt!)}까지 혜택 유지')
                            : '주제 ${AppLimits.plusActiveTopics}개 · 하루 신청 무제한',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.tertiary,
                ),
              ],
            ),
          ),

          if (mine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            SectionCard(
              onTap: () => context.push(Routes.spotMe),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const IconTile(Icons.place_rounded),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          db.spot(mine.first.spotId)?.name ?? '',
                          style: AppTypography.subtitle,
                        ),
                        Text(
                          '체크인 중 · ${TimeFormat.clock(mine.first.startedAt)}부터',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.tertiary,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm + 2),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                _Menu(
                  icon: Icons.block_rounded,
                  label: '차단 목록',
                  trailing: db.blocks.isEmpty ? null : '${db.blocks.length}명',
                  onTap: () => context.push(Routes.myBlocked),
                ),
                _Menu(
                  icon: Icons.fact_check_outlined,
                  label: '동의 내역',
                  onTap: () => context.push(Routes.myConsent),
                ),
                _Menu(
                  icon: Icons.menu_book_rounded,
                  label: '사용법 가이드',
                  onTap: () => context.push(Routes.myGuide),
                ),
                _Menu(
                  icon: Icons.manage_accounts_outlined,
                  label: '계정',
                  onTap: () => context.push(Routes.myAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider() =>
      Container(width: 1, height: 28, color: AppColors.hairline);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.title),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      leading: Icon(icon, color: AppColors.secondary, size: 22),
      title: label,
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: AppTypography.body.copyWith(color: AppColors.secondary),
            ),
    );
  }
}
