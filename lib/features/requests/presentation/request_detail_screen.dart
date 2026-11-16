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
import '../../safety/presentation/safety_menu.dart';

/// 신청함 > 받은 신청 > 신청 상세 (US-008)
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final r = db.request(requestId);
    if (r == null || db.isBlocked(r.fromUid)) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.inbox_outlined,
          title: '볼 수 없는 신청이에요',
        ),
      );
    }
    final from = db.user(r.fromUid);
    final myCard = db.checkin(r.toCheckinId);
    final isPending = r.status == ChatRequestStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('받은 신청'),
        actions: [
          SafetyMenuButton(
            targetUid: r.fromUid,
            source: ReportSource.request,
            iconColor: AppColors.heading,
            onBlocked: () => context.pop(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    InitialAvatar(r.fromNickname, size: 56),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.fromNickname, style: AppTypography.display),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                r.fromJobLabel,
                                style: AppTypography.caption,
                              ),
                              if (from?.hasTrustBadge ?? false) ...[
                                const SizedBox(width: AppSpacing.sm),
                                const TrustBadge(),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text('한 마디', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    '“${r.message}”',
                    style: AppTypography.subtitle.copyWith(height: 1.6),
                  ),
                ),
                if (myCard != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text('신청받은 내 주제', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.xs),
                  Text(myCard.topic, style: AppTypography.body),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(switch (r.status) {
                        ChatRequestStatus.pending =>
                          '${TimeFormat.remaining(r.expiresAt.difference(now))} · 답하지 않으면 자동으로 끝나요',
                        ChatRequestStatus.accepted => '수락한 신청이에요',
                        ChatRequestStatus.rejected => '거절한 신청이에요',
                        ChatRequestStatus.expired => '시간이 지나 끝난 신청이에요',
                      }, style: AppTypography.caption),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPending)
            BottomCta(
              top: Text(
                '거절해도 상대에게는 “이번엔 어렵대요”만 보이고 사유는 알리지 않아요.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO(firebase): chatRequests/{id}.status = rejected
                        ref
                            .read(demoStoreProvider.notifier)
                            .respond(r.id, accept: false);
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신청을 거절했어요')),
                        );
                      },
                      child: const Text('거절'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        // TODO(firebase): 수락 → Functions가 chats 문서 생성
                        final chatId = ref
                            .read(demoStoreProvider.notifier)
                            .respond(r.id, accept: true);
                        if (chatId != null) context.go(Routes.chatRoom(chatId));
                      },
                      child: const Text('수락하고 대화하기'),
                    ),
                  ),
                ],
              ),
            )
          else if (r.status == ChatRequestStatus.accepted && r.chatId != null)
            BottomCta(
              child: FilledButton(
                onPressed: () => context.go(Routes.chatRoom(r.chatId!)),
                child: const Text('대화방으로 가기'),
              ),
            ),
        ],
      ),
    );
  }
}
