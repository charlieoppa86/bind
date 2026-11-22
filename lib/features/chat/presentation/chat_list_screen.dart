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
              message: '요청이 수락되거나 그룹 채팅에 들어가면 여기서 대화를 이어갈 수 있어요.',
            )
          : ListView.builder(
              itemCount: ids.length,
              itemBuilder: (_, i) =>
                  _ChatRow(key: ValueKey(ids[i]), chatId: ids[i]),
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
    // 방 종류는 바뀌지 않으므로 1:1일 때만 상대 프로필을 구독한다.
    final String name;
    final String? job;
    final bool left;
    if (chat.isGroup) {
      name = chat.title ?? ChatType.group.label;
      job = null;
      left = false;
    } else {
      final otherUid = chat.otherUid(DemoDb.myUid);
      final (nickname, jobLabel, deleted) = ref.watch(
        userProvider(
          otherUid,
        ).select((u) => (u?.nickname ?? '', u?.jobLabel, u?.deleted ?? false)),
      );
      name = nickname;
      job = jobLabel;
      left = chat.leftUids.contains(otherUid) || deleted;
    }
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
            if (chat.isGroup)
              const GroupAvatar(size: 48)
            else
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
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.xs + 2,
                        ),
                        child: StatusPill(
                          chat.isGroup
                              ? '${ChatType.group.label} · ${chat.activeMemberCount}명'
                              : ChatType.direct.label,
                          tone: chat.isGroup ? PillTone.active : PillTone.muted,
                        ),
                      ),
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
                      ],
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
