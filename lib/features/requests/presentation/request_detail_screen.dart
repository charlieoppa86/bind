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
import '../../safety/presentation/safety_menu.dart';

/// 요청함 > 받은 요청 > 요청 상세 (US-008)
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  /// 수락하면 대화방으로, 거절하면 이전 화면으로. 실제 모드는 서버가 처리한다.
  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool accept,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final String? chatId;
    try {
      chatId = await ref
          .read(demoStoreProvider.notifier)
          .respondTo(id, accept: accept);
    } catch (e) {
      debugPrint('[BIND] 요청 응답 실패: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('처리하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    if (!context.mounted) return;
    if (accept && chatId != null) {
      context.go(Routes.chatRoom(chatId));
    } else if (accept) {
      messenger.showSnackBar(const SnackBar(content: Text('시간이 지나 끝난 요청이에요')));
    } else {
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('요청을 거절했어요')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(requestProvider(requestId));
    final blocked = r != null && ref.watch(isBlockedProvider(r.fromUid));
    if (r == null || blocked) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.inbox_outlined,
          title: '볼 수 없는 요청이에요',
        ),
      );
    }
    final trusted = ref.watch(
      userProvider(r.fromUid).select((u) => u?.hasTrustBadge ?? false),
    );
    final myTopic = ref.watch(
      checkinProvider(r.toCheckinId).select((c) => c?.topic),
    );
    final isPending = r.status == ChatRequestStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('대화 요청'),
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
                              if (trusted) ...[
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
                const Text('하고 싶은 대화', style: AppTypography.caption),
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
                if (myTopic != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text('내 주제', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.xs),
                  Text(myTopic, style: AppTypography.body),
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
                      child: switch (r.status) {
                        ChatRequestStatus.pending => _Remaining(r.expiresAt),
                        ChatRequestStatus.accepted => const Text(
                          '수락한 요청이에요',
                          style: AppTypography.caption,
                        ),
                        ChatRequestStatus.rejected => const Text(
                          '거절한 요청이에요',
                          style: AppTypography.caption,
                        ),
                        ChatRequestStatus.expired => const Text(
                          '시간이 지나 끝난 요청이에요',
                          style: AppTypography.caption,
                        ),
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPending)
            BottomCta(
              top: const Text(
                '수락하면 바로 1:1 대화가 시작돼요. 거절해도 상대에게는 “이번엔 어렵대요”만 보여요.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond(context, ref, r.id, false),
                      child: const Text('거절'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => _respond(context, ref, r.id, true),
                      child: const Text('수락하고 대화 시작'),
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

/// 남은 시간 — 시계만 구독
class _Remaining extends ConsumerWidget {
  const _Remaining(this.expiresAt);

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(
      clockProvider.select(
        (now) => TimeFormat.remaining(expiresAt.difference(now)),
      ),
    );
    return Text('$left · 답하지 않으면 자동으로 끝나요', style: AppTypography.caption);
  }
}
