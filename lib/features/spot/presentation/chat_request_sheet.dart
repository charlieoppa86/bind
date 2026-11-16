import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';
import '../../my/presentation/plus_prompt.dart';

/// 스팟 > 스팟 피드 > 대화 신청 (바텀시트, US-007)
class ChatRequestSheet extends ConsumerStatefulWidget {
  const ChatRequestSheet({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ChatRequestSheet> createState() => _ChatRequestSheetState();
}

class _ChatRequestSheetState extends ConsumerState<ChatRequestSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final db = ref.read(demoStoreProvider);
    final now = DateTime.now();
    final mine = db.myCheckins(now);
    final target = mine.isEmpty
        ? null
        : db
              .feed(mine.first.spotId, now)
              .where((c) => c.uid == widget.userId)
              .firstOrNull;
    if (target == null) return;

    // TODO(firebase): chatRequests 문서 생성 + 상대에게 FCM
    final result = ref
        .read(demoStoreProvider.notifier)
        .sendRequest(target, _controller.text);
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case SendRequestResult.sent:
        context.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${target.nickname}님에게 신청을 보냈어요. '
              '${AppLimits.requestExpiry.inMinutes}분 안에 답이 없으면 자동으로 끝나요.',
            ),
          ),
        );
      case SendRequestResult.dailyLimit:
        await showPlusPrompt(
          context,
          reason: '무료로는 하루 ${AppLimits.freeDailyRequests}번까지 신청할 수 있어요.',
        );
      case SendRequestResult.duplicate:
      case SendRequestResult.notCheckedIn:
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final mine = db.myCheckins(now);
    final target = mine.isEmpty
        ? null
        : db
              .feed(mine.first.spotId, now)
              .where((c) => c.uid == widget.userId)
              .firstOrNull;
    final pending = db.pendingTo(widget.userId);
    final leftToday = AppLimits.freeDailyRequests - db.sentToday(now);
    final canSend =
        target != null &&
        pending == null &&
        _controller.text.trim().length >= AppLimits.requestMessageMin;

    if (target == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('이 카드는 더 이상 볼 수 없어요. 상대가 체크아웃했어요.'),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialAvatar(target.nickname, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(target.nickname, style: AppTypography.title),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '· ${target.jobTag.label}',
                            style: AppTypography.caption,
                          ),
                          if (target.hasTrustBadge) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const TrustBadge(),
                          ],
                        ],
                      ),
                      Text(target.category.label, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                target.topic,
                style: AppTypography.title.copyWith(fontSize: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (pending != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이미 신청했어요',
                      style: AppTypography.supportingTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('“${pending.message}”', style: AppTypography.body),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '답을 기다리는 중 · ${TimeFormat.remaining(pending.expiresAt.difference(now))}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                '왜 얘기하고 싶은지 한 마디',
                style: AppTypography.supportingTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                maxLength: AppLimits.requestMessageMax,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '예) 저도 같은 고민 중이에요! 10분만 얘기해요',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (!db.isPlusActive)
                Text(
                  leftToday > 0
                      ? '오늘 남은 무료 신청 $leftToday번'
                      : '오늘 무료 신청을 모두 썼어요',
                  style: AppTypography.caption,
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: canSend ? _send : null,
              child: const Text('신청 보내기'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '상대가 수락하면 1:1 대화가 열려요. 수락 전에는 대화할 수 없어요.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
