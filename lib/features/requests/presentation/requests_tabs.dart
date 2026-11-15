import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/models/chat_request.dart';

/// 신청함 탭(받은 신청 / 보낸 신청) 공통 상단 탭바.
/// 하위 탭이 각각 라우트를 갖도록 TabBar 선택 시 go로 이동한다.
class _RequestsTabsScaffold extends ConsumerWidget {
  const _RequestsTabsScaffold({required this.index, required this.body});

  final int index;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(demoStoreProvider).pendingReceivedCount;
    return DefaultTabController(
      key: ValueKey(index),
      length: 2,
      initialIndex: index,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: AppSpacing.page,
          title: const Text('신청함', style: AppTypography.title),
          bottom: TabBar(
            onTap: (i) {
              if (i == index) return;
              context.go(
                i == 0 ? Routes.requestsReceived : Routes.requestsSent,
              );
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('받은 신청'),
                    if (pending > 0) ...[
                      const SizedBox(width: AppSpacing.xs),
                      CountBadge(pending),
                    ],
                  ],
                ),
              ),
              const Tab(text: '보낸 신청'),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

class ReceivedRequestsScreen extends ConsumerWidget {
  const ReceivedRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final all = db.received();
    final pending = all
        .where((r) => r.status == ChatRequestStatus.pending)
        .toList();
    final done = all
        .where((r) => r.status != ChatRequestStatus.pending)
        .toList();
    final checkedIn = db.myCheckins(now).isNotEmpty;

    return _RequestsTabsScaffold(
      index: 0,
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.inbox_outlined,
              title: '아직 받은 신청이 없어요',
              message: checkedIn
                  ? '같은 스팟 사람이 신청하면 여기에 보여요.\n신청은 ${AppLimits.requestExpiry.inMinutes}분 안에 답해야 해요.'
                  : '스팟에 체크인하고 주제를 올리면\n대화 신청을 받을 수 있어요.',
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
                  SectionLabel('답을 기다리는 신청 ${pending.length}'),
                  for (final r in pending) _ReceivedTile(request: r, now: now),
                ],
                if (done.isNotEmpty) ...[
                  const SectionLabel('지난 신청'),
                  for (final r in done) _ReceivedTile(request: r, now: now),
                ],
              ],
            ),
    );
  }
}

class _ReceivedTile extends ConsumerWidget {
  const _ReceivedTile({required this.request, required this.now});

  final ChatRequest request;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final isPending = r.status == ChatRequestStatus.pending;
    final left = r.expiresAt.difference(now);
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
                      Text(
                        '· ${r.fromJobTag.label}',
                        style: AppTypography.caption,
                      ),
                      const Spacer(),
                      Text(
                        TimeFormat.relative(r.createdAt, now),
                        style: AppTypography.caption,
                      ),
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
                    ChatRequestStatus.pending => StatusPill(
                      '${TimeFormat.remaining(left)} · 지금 답해 주세요',
                      tone: PillTone.active,
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
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final sent = db.sent();
    return _RequestsTabsScaffold(
      index: 1,
      body: sent.isEmpty
          ? const EmptyState(
              icon: Icons.send_outlined,
              title: '보낸 신청이 없어요',
              message: '스팟 피드에서 관심 가는 주제 카드에 대화를 신청해 보세요.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: sent.length,
              separatorBuilder: (_, _) => const Divider(
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
              itemBuilder: (_, i) {
                final r = sent[i];
                final other = db.user(r.toUid);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InitialAvatar(other?.nickname ?? ''),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  other?.nickname ?? '알 수 없음',
                                  style: AppTypography.supportingTitle,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '· ${db.spot(r.spotId)?.name ?? ''}',
                                  style: AppTypography.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('“${r.message}”', style: AppTypography.body),
                            const SizedBox(height: AppSpacing.sm),
                            _SentStatus(request: r, now: now),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SentStatus extends StatelessWidget {
  const _SentStatus({required this.request, required this.now});

  final ChatRequest request;
  final DateTime now;

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
          Text(
            '답을 기다리는 중 · ${TimeFormat.remaining(r.expiresAt.difference(now))}',
            style: AppTypography.caption,
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
      ChatRequestStatus.expired => const StatusPill('답이 없어 신청이 끝났어요'),
    };
  }
}
