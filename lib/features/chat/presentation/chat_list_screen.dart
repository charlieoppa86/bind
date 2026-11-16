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

/// 채팅 > 대화 목록 (US-012)
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final chats = db.visibleChats(now);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        title: const Text('채팅', style: AppTypography.title),
      ),
      body: chats.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: '아직 대화가 없어요',
              message: '신청이 수락되면 여기서 1:1 대화를 이어갈 수 있어요.',
            )
          : ListView(
              children: [
                Padding(
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
                ),
                for (final chat in chats)
                  () {
                    final otherUid = chat.otherUid(DemoDb.myUid);
                    final other = db.user(otherUid);
                    final left =
                        chat.leftUids.contains(otherUid) ||
                        (other?.deleted ?? false);
                    final unread = db.unread[chat.id] ?? 0;
                    final daysLeft = chat.expiresAt.difference(now).inDays;
                    return Pressable(
                      borderRadius: 0,
                      onTap: () => context.push(Routes.chatRoom(chat.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            InitialAvatar(
                              left ? '' : (other?.nickname ?? ''),
                              size: 48,
                              dimmed: left,
                            ),
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
                                                left
                                                    ? '떠난 사용자'
                                                    : other?.nickname ?? '',
                                                style: AppTypography
                                                    .supportingTitle
                                                    .copyWith(
                                                      color: left
                                                          ? AppColors.secondary
                                                          : AppColors.heading,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!left && other != null) ...[
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Text(
                                                '· ${other.jobLabel}',
                                                style: AppTypography.caption,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        TimeFormat.relative(
                                          chat.lastMessageAt ?? chat.createdAt,
                                          now,
                                        ),
                                        style: AppTypography.caption,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat.lastMessage ??
                                              '대화가 열렸어요. 먼저 인사해 보세요!',
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
                                      ] else if (daysLeft <= 1) ...[
                                        const SizedBox(width: AppSpacing.sm),
                                        const StatusPill(
                                          '곧 사라져요',
                                          tone: PillTone.muted,
                                        ),
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
                  }(),
              ],
            ),
    );
  }
}
