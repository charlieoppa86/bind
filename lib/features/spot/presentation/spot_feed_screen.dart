import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/models/checkin.dart';
import '../../checkin/presentation/room_pin_screen.dart';
import '../../safety/presentation/safety_menu.dart';

/// 스팟 > 스팟 피드 (US-006, US-015). 체크인 후 홈.
class SpotFeedScreen extends ConsumerStatefulWidget {
  const SpotFeedScreen({super.key});

  @override
  ConsumerState<SpotFeedScreen> createState() => _SpotFeedScreenState();
}

class _SpotFeedScreenState extends ConsumerState<SpotFeedScreen> {
  TopicCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final mine = db.myCheckins(now);
    if (mine.isEmpty) return const Scaffold();
    final spot = db.spot(mine.first.spotId);
    final all = db.feed(mine.first.spotId, now);
    final cards = _filter == null
        ? all
        : all.where((c) => c.category == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: AppColors.groupedBackground,
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        toolbarHeight: 64,
        actions: [
          if (db.isCreator(mine.first.spotId))
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Pressable(
                onTap: () => showRoomPinSheet(context, mine.first.spotId),
                color: AppColors.canvas,
                borderRadius: AppRadius.full,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.key_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '입장 PIN',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spot?.name ?? '', style: AppTypography.title),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '지금 ${db.headcount(mine.first.spotId, now)}명이 체크인 중',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 400)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _MyCard(cards: mine, now: now),
            ),
            if (all.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategoryFilter(
                  selected: _filter,
                  counts: {
                    for (final c in TopicCategory.values)
                      c: all.where((x) => x.category == c).length,
                  },
                  total: all.length,
                  onSelected: (c) => setState(() => _filter = c),
                ),
              ),
            if (all.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptySpot(
                  notifyOn: mine.first.notifyWhenSomeoneArrives,
                ),
              )
            else if (cards.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: '이 카테고리의 주제는 아직 없어요',
                  message: '다른 카테고리를 골라보세요.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverList.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm + 2),
                  itemBuilder: (_, i) => TopicCard(
                    checkin: cards[i],
                    now: now,
                    pending: db.pendingTo(cards[i].uid) != null,
                    chatId: db.chatWith(cards[i].uid, now)?.id,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 다른 사람의 주제 카드: 닉네임·직무·주제·남은 시간만(US-006)
class TopicCard extends StatelessWidget {
  const TopicCard({
    required this.checkin,
    required this.now,
    required this.pending,
    this.chatId,
    super.key,
  });

  final Checkin checkin;
  final DateTime now;
  final bool pending;

  /// 이미 대화 중이면 그 대화방
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    final c = checkin;
    final left = c.remaining(now);
    final endingSoon = left.inMinutes < 30;
    return Pressable(
      color: AppColors.canvas,
      onTap: () => context.push(
        chatId != null ? Routes.chatRoom(chatId!) : Routes.spotRequest(c.uid),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialAvatar(c.nickname, size: 36),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.nickname,
                              style: AppTypography.supportingTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.hasTrustBadge) ...[
                            const SizedBox(width: AppSpacing.xs + 2),
                            const TrustBadge(),
                          ],
                        ],
                      ),
                      Text(c.jobTag.label, style: AppTypography.caption),
                    ],
                  ),
                ),
                SafetyMenuButton(targetUid: c.uid, source: ReportSource.feed),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Text(
                c.topic,
                style: AppTypography.title.copyWith(fontSize: 18, height: 1.45),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: endingSoon ? AppColors.error : AppColors.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${c.category.label} · ${TimeFormat.remaining(left)}',
                      style: AppTypography.caption.copyWith(
                        color: endingSoon
                            ? AppColors.error
                            : AppColors.secondary,
                      ),
                    ),
                  ),
                  if (chatId != null)
                    const StatusPill('대화 중', tone: PillTone.active)
                  else if (pending)
                    const StatusPill('답을 기다리는 중')
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Text(
                        '대화 신청',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCard extends StatelessWidget {
  const _MyCard({required this.cards, required this.now});

  final List<Checkin> cards;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final left = cards.first.remaining(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Pressable(
        onTap: () => context.push(Routes.spotMe),
        color: AppColors.heading,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cards.length > 1 ? '내 주제 ${cards.length}개' : '내 주제',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final c in cards)
                      Text(
                        c.topic,
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.onPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    TimeFormat.remaining(left),
                    style: AppTypography.body.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '체크인 관리',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.counts,
    required this.total,
    required this.onSelected,
  });

  final TopicCategory? selected;
  final Map<TopicCategory, int> counts;
  final int total;
  final ValueChanged<TopicCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      SelectChip(
        label: '전체 $total',
        compact: true,
        selected: selected == null,
        onTap: () => onSelected(null),
      ),
      for (final c in TopicCategory.values)
        if ((counts[c] ?? 0) > 0)
          SelectChip(
            label: '${c.label} ${counts[c]}',
            compact: true,
            selected: selected == c,
            onTap: () => onSelected(c),
          ),
    ];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs + 2),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// 같은 스팟에 아무도 없을 때(US-006 AC3, US-015)
class _EmptySpot extends ConsumerWidget {
  const _EmptySpot({required this.notifyOn});

  final bool notifyOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                const IconTile(
                  Icons.people_outline_rounded,
                  size: 64,
                  iconColor: AppColors.tertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '아직 아무도 없어요',
                  style: AppTypography.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '곧 누군가 체크인할 거예요.\n주제를 구체적으로 바꾸면 신청을 받기 쉬워요.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () => context.push(Routes.spotMe),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                  child: const Text('내 주제 수정'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SectionCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                const IconTile(Icons.notifications_active_outlined),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('누가 오면 알려줘', style: AppTypography.subtitle),
                      Text(
                        '첫 사람이 체크인하면 한 번 알려드려요',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: notifyOn,
                  onChanged: (v) =>
                      ref.read(demoStoreProvider.notifier).setArrivalNotify(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
