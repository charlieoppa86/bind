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
import '../../../data/demo/demo_store.dart';
import '../../../core/widgets/bind_logo.dart';

/// 대화방 id 목록(최근 메시지순). 순서가 같으면 목록은 다시 그리지 않는다.
final _chatIdsProvider = Provider.autoDispose<List<String>>((ref) {
  final key = ref.watch(
    visibleChatsProvider.select(
      (list) => [for (final c in list) c.id].join(','),
    ),
  );
  return key.isEmpty ? const [] : key.split(',');
});

/// 채팅 > 대화 목록 (US-012)
///
/// 목록은 방 순서만, 각 줄은 자기 방·상대·안 읽은 수만, 시간은 시계만 구독한다.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(_chatIdsProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        title: const BrandedTitle(
          child: Text('채팅', style: AppTypography.title),
        ),
      ),
      body: ids.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: '아직 대화가 없어요',
              message: '요청이 수락되면 여기서 1:1 대화를 이어갈 수 있어요.',
            )
          : ListView.builder(
              itemCount: ids.length + 1,
              itemBuilder: (_, i) => i == 0
                  ? const _RetentionNote()
                  : _ChatRow(key: ValueKey(ids[i - 1]), chatId: ids[i - 1]),
            ),
    );
  }
}

class _RetentionNote extends StatelessWidget {
  const _RetentionNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        '대화는 시작하고 ${AppLimits.chatRetention.inDays}일이 지나면 사라져요',
        style: AppTypography.caption,
      ),
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chatId, super.key});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider(chatId));
    if (chat == null) return const SizedBox.shrink();
    final otherUid = chat.otherUid(DemoDb.myUid);
    final (name, job, deleted) = ref.watch(
      userProvider(otherUid)
          .select((u) => (u?.nickname ?? '', u?.jobLabel, u?.deleted ?? false)),
    );
    final left = chat.leftUids.contains(otherUid) || deleted;
    final unread = ref.watch(unreadProvider(chatId));

    return Pressable(
      borderRadius: 0,
      onTap: () => context.push(Routes.chatRoom(chatId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            InitialAvatar(left ? '' : name, size: 48, dimmed: left),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                left ? '떠난 사용자' : name,
                                style: AppTypography.supportingTitle.copyWith(
                                  color: left
                                      ? AppColors.secondary
                                      : AppColors.heading,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!left && job != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text('· $job', style: AppTypography.caption),
                            ],
                          ],
                        ),
                      ),
                      _RelativeTime(chat.lastMessageAt ?? chat.createdAt),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? '대화가 열렸어요. 먼저 인사해 보세요!',
                          style: AppTypography.body.copyWith(
                            color: unread > 0
                                ? AppColors.heading
                                : AppColors.secondary,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        CountBadge(unread),
                      ] else
                        _ExpiringSoon(chat.expiresAt),
                    ],
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

/// "방금 / n분 전 / 오후 3:10" — 시계만 구독
class _RelativeTime extends ConsumerWidget {
  const _RelativeTime(this.time);

  final DateTime time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    return Text(TimeFormat.relative(time, now), style: AppTypography.caption);
  }
}

/// 보관 기간이 하루 안으로 남았으면 "곧 사라져요" — 시계만 구독
class _ExpiringSoon extends ConsumerWidget {
  const _ExpiringSoon(this.expiresAt);

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soon = ref.watch(
      clockProvider.select((now) => expiresAt.difference(now).inDays <= 1),
    );
    if (!soon) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(left: AppSpacing.sm),
      child: StatusPill('곧 사라져요', tone: PillTone.muted),
    );
  }
}
