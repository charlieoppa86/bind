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
import '../../../data/demo/demo_providers.dart';

/// 마이 > 마이
///
/// 화면은 아무것도 구독하지 않고, 카드마다 자기 데이터만 구독한다.
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        children: const [
          _ProfileCard(),
          SizedBox(height: AppSpacing.sm + 2),
          _PlusCard(),
          _CheckinCard(),
          SizedBox(height: AppSpacing.sm + 2),
          _MenuCard(),
        ],
      ),
    );
  }
}

/// 프로필 + 활동 숫자 + 신뢰 표시 안내
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (name, job, good, badge) = ref.watch(
      meProvider.select(
        (m) => (
          m?.nickname ?? '',
          m?.jobLabel ?? '',
          m?.goodReviewCount ?? 0,
          m?.hasTrustBadge ?? false,
        ),
      ),
    );
    final toBadge = AppLimits.trustBadgeThreshold - good;

    return SectionCard(
      onTap: () => context.push(Routes.myProfile),
      child: Column(
        children: [
          Row(
            children: [
              InitialAvatar(name, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppTypography.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge) ...const [
                          SizedBox(width: AppSpacing.sm),
                          TrustBadge(),
                        ],
                      ],
                    ),
                    Text(
                      '$job · 프로필 수정',
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
                _Stat(label: '받은 좋았어요', value: '$good'),
                const _StatDivider(),
                const _ChatCountStat(),
                const _StatDivider(),
                const _SentTodayStat(),
              ],
            ),
          ),
          if (!badge) ...[
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
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.hairline);
}

class _ChatCountStat extends ConsumerWidget {
  const _ChatCountStat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(visibleChatsProvider.select((l) => l.length));
    return _Stat(label: '진행 중 대화', value: '$count');
  }
}

class _SentTodayStat extends ConsumerWidget {
  const _SentTodayStat();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _Stat(label: '오늘 보낸 요청', value: '${ref.watch(sentTodayProvider)}');
}

class _PlusCard extends ConsumerWidget {
  const _PlusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(isPlusActiveProvider);
    final autoRenew = ref.watch(plusAutoRenewProvider);
    final until = ref.watch(meProvider.select((m) => m?.plusExpiresAt));
    return SectionCard(
      onTap: () => context.push(Routes.myPlus),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const IconTile(
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
                  active ? 'BIND+ 이용 중' : 'BIND+ 시작하기',
                  style: AppTypography.subtitle,
                ),
                Text(
                  active && until != null
                      ? (autoRenew
                            ? '${TimeFormat.date(until)}에 자동 갱신'
                            : '${TimeFormat.date(until)}까지 혜택 유지')
                      : '주제 ${AppLimits.plusActiveTopics}개 · 하루 요청 무제한',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.tertiary),
        ],
      ),
    );
  }
}

/// 체크인 중일 때만 보이는 카드
class _CheckinCard extends ConsumerWidget {
  const _CheckinCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = ref.watch(myCheckinsProvider.select((l) => l.firstOrNull));
    if (first == null) return const SizedBox.shrink();
    final name = ref.watch(
      spotProvider(first.spotId).select((s) => s?.name ?? ''),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
      child: SectionCard(
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
                  Text(name, style: AppTypography.subtitle),
                  Text(
                    '체크인 중 · ${TimeFormat.clock(first.startedAt)}부터',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.tertiary),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends ConsumerWidget {
  const _MenuCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blocksProvider.select((l) => l.length));
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          _Menu(
            icon: Icons.block_rounded,
            label: '차단 목록',
            trailing: blocked == 0 ? null : '$blocked명',
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
    );
  }
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
