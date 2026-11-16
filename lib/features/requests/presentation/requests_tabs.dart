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
import '../../../data/demo/demo_providers.dart';
import '../../../data/models/chat_request.dart';

/// 요청함 탭(받은 요청 / 보낸 요청) 공통 상단 탭바.
/// 하위 탭이 각각 라우트를 갖도록 TabBar 선택 시 go로 이동한다.
class _RequestsTabsScaffold extends StatelessWidget {
  const _RequestsTabsScaffold({required this.index, required this.body});

  final int index;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(index),
      length: 2,
      initialIndex: index,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: AppSpacing.page,
          title: const Text('요청함', style: AppTypography.title),
          bottom: TabBar(
            onTap: (i) {
              if (i == index) return;
              context.go(
                i == 0 ? Routes.requestsReceived : Routes.requestsSent,
              );
            },
            tabs: const [
              Tab(child: _ReceivedTabLabel()),
              Tab(text: '보낸 요청'),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

/// "받은 요청 n" — 대기 수만 구독
class _ReceivedTabLabel extends ConsumerWidget {
  const _ReceivedTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingReceivedCountProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('받은 요청'),
        if (pending > 0) ...[
          const SizedBox(width: AppSpacing.xs),
          CountBadge(pending),
        ],
      ],
    );
  }
}

class ReceivedRequestsScreen extends ConsumerWidget {
  const ReceivedRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(receivedRequestsProvider);
    final pending = all
        .where((r) => r.status == ChatRequestStatus.pending)
        .toList();
    final done = all
        .where((r) => r.status != ChatRequestStatus.pending)
        .toList();
    final checkedIn = ref.watch(mySpotIdProvider) != null;

    return _RequestsTabsScaffold(
      index: 0,
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.inbox_outlined,
              title: '아직 받은 요청이 없어요',
              message: checkedIn
                  ? '같은 장소 사람이 대화를 요청하면 여기에 보여요.\n수락하면 바로 대화가 시작돼요.'
                  : '장소에 체크인하고 주제를 올리면\n대화 요청을 받을 수 있어요.',
              action: checkedIn
                  ? null
                  : FilledButton(
                      onPressed: () => context.go(Routes.checkinSpots),
                      child: const Text('체크인하러 가기'),
                    ),
            )
          : ListView(
              children: [
                if (pending.isNotEmpty) ...[
                  SectionLabel('수락을 기다리는 요청 ${pending.length}'),
                  for (final r in pending)
                    _ReceivedTile(key: ValueKey(r.id), request: r),
                ],
                if (done.isNotEmpty) ...[
                  const SectionLabel('지난 요청'),
                  for (final r in done)
                    _ReceivedTile(key: ValueKey(r.id), request: r),
                ],
              ],
            ),
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({required this.request, super.key});

  final ChatRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final isPending = r.status == ChatRequestStatus.pending;
    return Pressable(
      borderRadius: 0,
      onTap: () => context.push(Routes.requestDetail(r.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(r.fromNickname, dimmed: !isPending),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        r.fromNickname,
                        style: AppTypography.supportingTitle.copyWith(
                          color: isPending
                              ? AppColors.heading
                              : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text('· ${r.fromJobLabel}', style: AppTypography.caption),
                      const Spacer(),
                      _RelativeTime(r.createdAt),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.message,
                    style: AppTypography.body.copyWith(
                      color: isPending ? AppColors.body : AppColors.secondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  switch (r.status) {
                    ChatRequestStatus.pending => _Remaining(
                      r.expiresAt,
                      builder: (left) => StatusPill(
                        '$left · 수락하면 대화 시작',
                        tone: PillTone.active,
                      ),
                    ),
                    ChatRequestStatus.accepted => const StatusPill(
                      '수락함',
                      tone: PillTone.muted,
                    ),
                    ChatRequestStatus.rejected => const StatusPill(
                      '거절함',
                      tone: PillTone.muted,
                    ),
                    ChatRequestStatus.expired => const StatusPill(
                      '시간이 지나 끝남',
                      tone: PillTone.muted,
                    ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SentRequestsScreen extends ConsumerWidget {
  const SentRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(sentRequestsProvider);
    return _RequestsTabsScaffold(
      index: 1,
      body: sent.isEmpty
          ? const EmptyState(
              icon: Icons.send_outlined,
              title: '보낸 요청이 없어요',
              message: '피드에서 관심 가는 주제 카드에 대화를 요청해 보세요.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: sent.length,
              separatorBuilder: (_, _) => const Divider(
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
              itemBuilder: (_, i) =>
                  _SentTile(key: ValueKey(sent[i].id), request: sent[i]),
            ),
    );
  }
}

class _SentTile extends ConsumerWidget {
  const _SentTile({required this.request, super.key});

  final ChatRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final nickname = ref.watch(
      userProvider(r.toUid).select((u) => u?.nickname),
    );
    final place = ref.watch(spotProvider(r.spotId).select((s) => s?.name));
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialAvatar(nickname ?? ''),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nickname ?? '알 수 없음',
                      style: AppTypography.supportingTitle,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '· ${place ?? ''}',
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('“${r.message}”', style: AppTypography.body),
                const SizedBox(height: AppSpacing.sm),
                _SentStatus(request: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentStatus extends StatelessWidget {
  const _SentStatus({required this.request});

  final ChatRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return switch (r.status) {
      ChatRequestStatus.pending => Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Remaining(
            r.expiresAt,
            builder: (left) =>
                Text('수락 대기 중 · $left', style: AppTypography.caption),
          ),
        ],
      ),
      ChatRequestStatus.accepted => Row(
        children: [
          const StatusPill('수락됐어요', tone: PillTone.active),
          const Spacer(),
          if (r.chatId != null)
            TextButton(
              onPressed: () => context.push(Routes.chatRoom(r.chatId!)),
              child: const Text('대화하기'),
            ),
        ],
      ),
      // US-008: 거절 사유는 드러내지 않는다.
      ChatRequestStatus.rejected => const StatusPill('이번엔 어렵대요'),
      ChatRequestStatus.expired => const StatusPill('답이 없어 요청이 끝났어요'),
    };
  }
}

/// "n분 전" — 시계만 구독
class _RelativeTime extends ConsumerWidget {
  const _RelativeTime(this.time);

  final DateTime time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    return Text(TimeFormat.relative(time, now), style: AppTypography.caption);
  }
}

/// 만료까지 남은 시간 — 시계만 구독, 표시 글자가 바뀔 때만 다시 그린다.
class _Remaining extends ConsumerWidget {
  const _Remaining(this.expiresAt, {required this.builder});

  final DateTime expiresAt;
  final Widget Function(String left) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(
      clockProvider.select(
        (now) => TimeFormat.remaining(expiresAt.difference(now)),
      ),
    );
    return builder(left);
  }
}
