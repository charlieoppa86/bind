import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/models/checkin.dart';
import '../../safety/presentation/safety_menu.dart';
import '../../../core/widgets/bind_logo.dart';

/// 피드 카테고리 필터(화면 안 상태). 필터를 바꿔도 필터 바와 목록만 다시 그린다.
class _FeedFilter extends Notifier<TopicCategory?> {
  @override
  TopicCategory? build() => null;

  void select(TopicCategory? c) => state = c;
}

final _feedFilterProvider =
    NotifierProvider.autoDispose<_FeedFilter, TopicCategory?>(_FeedFilter.new);

/// 스팟 > 스팟 피드 (US-006, US-015). 체크인 후 홈.
///
/// 화면 자체는 "지금 체크인한 장소 id"만 구독한다. 머리말·내 카드·필터·목록·
/// 카드 상태는 각각 필요한 것만 구독하는 작은 위젯으로 나눴다.
class SpotFeedScreen extends ConsumerWidget {
  const SpotFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotId = ref.watch(mySpotIdProvider);
    if (spotId == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: AppColors.groupedBackground,
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        toolbarHeight: 64,
        title: BrandedTitle(child: _FeedHeader(spotId)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 400)),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _MyCard()),
            _FeedSlivers(spotId),
          ],
        ),
      ),
    );
  }
}

/// 장소 이름 + 지금 인원
class _FeedHeader extends StatelessWidget {
  const _FeedHeader(this.spotId);

  final String spotId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SpotName(spotId),
        Row(
          children: [
            const _Dot(),
            const SizedBox(width: 6),
            _Headcount(spotId),
          ],
        ),
      ],
    );
  }
}

class _SpotName extends ConsumerWidget {
  const _SpotName(this.spotId);

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(spotProvider(spotId).select((s) => s?.name ?? ''));
    return Text(name, style: AppTypography.title);
  }
}

class _Headcount extends ConsumerWidget {
  const _Headcount(this.spotId);

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 인원 수에는 나도 들어 있어서, 나를 뺀 사람 수(n-1)를 보여 준다.
    final others = ref.watch(
      headcountProvider(spotId).select((n) => n > 0 ? n - 1 : 0),
    );
    return Text(
      others > 0 ? '지금 $others명이 같은 장소에 있어요' : '아직 같은 장소에 다른 사람이 없어요',
      style: AppTypography.caption.copyWith(color: AppColors.secondary),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
  );
}

/// 필터 + 카드 목록(또는 빈 상태)
class _FeedSlivers extends ConsumerWidget {
  const _FeedSlivers(this.spotId);

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(feedProvider(spotId));
    if (all.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptySpot(),
      );
    }
    final filter = ref.watch(_feedFilterProvider);
    final cards = filter == null
        ? all
        : all.where((c) => c.category == filter).toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _CategoryFilter(all: all)),
        if (cards.isEmpty)
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
              itemBuilder: (_, i) =>
                  TopicCard(key: ValueKey(cards[i].id), checkin: cards[i]),
            ),
          ),
      ],
    );
  }
}

/// 다른 사람의 주제 카드: 닉네임·직무·주제만(US-006)
///
/// 카드 본문은 체크인이 바뀔 때만, 오른쪽 아래 상태(대화 요청/대기/대화 중)는
/// 그 사람과의 요청·대화가 바뀔 때만 다시 그린다.
class TopicCard extends StatelessWidget {
  const TopicCard({required this.checkin, super.key});

  final Checkin checkin;

  @override
  Widget build(BuildContext context) {
    final c = checkin;
    return _CardTapTarget(
      uid: c.uid,
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
                          if (c.hasTrustBadge) ...const [
                            SizedBox(width: AppSpacing.xs + 2),
                            TrustBadge(),
                          ],
                        ],
                      ),
                      Text(c.jobLabel, style: AppTypography.caption),
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
                  const Icon(
                    Icons.tag_rounded,
                    size: 14,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.category.label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  _CardStatus(c.uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 누르면: 대화 중이면 대화방, 아니면 대화 요청 시트(누를 때만 읽는다)
class _CardTapTarget extends ConsumerWidget {
  const _CardTapTarget({required this.uid, required this.child});

  final String uid;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Pressable(
      color: AppColors.canvas,
      onTap: () {
        final chatId = ref.read(chatIdWithProvider(uid));
        context.push(
          chatId != null ? Routes.chatRoom(chatId) : Routes.spotRequest(uid),
        );
      },
      child: child,
    );
  }
}

class _CardStatus extends ConsumerWidget {
  const _CardStatus(this.uid);

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inChat = ref.watch(chatIdWithProvider(uid)) != null;
    if (inChat) return const StatusPill('대화 중', tone: PillTone.active);
    final pending = ref.watch(pendingToProvider(uid).select((r) => r != null));
    if (pending) return const StatusPill('수락 대기 중');
    return const _RequestButton();
  }
}

class _RequestButton extends StatelessWidget {
  const _RequestButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        '대화 요청',
        style: AppTypography.body.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 맨 위 내 주제 카드(내 주제 글자가 바뀔 때만 다시 그린다)
class _MyCard extends ConsumerWidget {
  const _MyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 주제 한 줄은 줄바꿈이 없으므로 문자열 하나로 묶어 값 비교한다.
    final topics = ref
        .watch(
          myCheckinsProvider.select(
            (list) => [for (final c in list) c.topic].join('\n'),
          ),
        )
        .split('\n');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Pressable(
        onTap: () => context.push(Routes.spotMe),
        color: AppColors.elevated,
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
                      topics.length > 1 ? '내 주제 ${topics.length}개' : '내 주제',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final t in topics)
                      Text(
                        t,
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.heading,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '체크인 관리',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondary,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter({required this.all});

  final List<Checkin> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_feedFilterProvider);
    final filter = ref.read(_feedFilterProvider.notifier);
    final counts = <TopicCategory, int>{};
    for (final c in all) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    final chips = <Widget>[
      SelectChip(
        label: '전체 ${all.length}',
        compact: true,
        selected: selected == null,
        onTap: () => filter.select(null),
      ),
      for (final c in TopicCategory.values)
        if ((counts[c] ?? 0) > 0)
          SelectChip(
            label: '${c.label} ${counts[c]}',
            compact: true,
            selected: selected == c,
            onTap: () => filter.select(c),
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

/// 같은 장소에 아무도 없을 때(US-006 AC3, US-015)
class _EmptySpot extends StatelessWidget {
  const _EmptySpot();

  @override
  Widget build(BuildContext context) {
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
                  '곧 누군가 체크인할 거예요.\n주제를 구체적으로 바꾸면 요청을 받기 쉬워요.',
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
          const SectionCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                IconTile(Icons.notifications_active_outlined),
                SizedBox(width: AppSpacing.md),
                Expanded(
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
                _ArrivalSwitch(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "누가 오면 알려줘" 스위치(내 체크인의 알림 설정만 구독)
class _ArrivalSwitch extends ConsumerWidget {
  const _ArrivalSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      myCheckinsProvider.select(
        (list) => list.firstOrNull?.notifyWhenSomeoneArrives ?? false,
      ),
    );
    return Switch(
      value: on,
      onChanged: (v) =>
          ref.read(demoStoreProvider.notifier).setArrivalNotify(v),
    );
  }
}
