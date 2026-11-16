import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import '../../my/presentation/plus_prompt.dart';

/// 스팟 > 스팟 피드 > 대화 요청 (바텀시트, US-007)
class ChatRequestSheet extends ConsumerStatefulWidget {
  const ChatRequestSheet({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ChatRequestSheet> createState() => _ChatRequestSheetState();
}

class _ChatRequestSheetState extends ConsumerState<ChatRequestSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

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

    final messenger = ScaffoldMessenger.of(context);
    final SendRequestResult result;
    setState(() => _sending = true);
    try {
      result = await ref
          .read(demoStoreProvider.notifier)
          .requestChat(target, _controller.text);
    } catch (e) {
      debugPrint('[BIND] 요청 보내기 실패: $e');
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('요청을 보내지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case SendRequestResult.sent:
        if (!context.mounted) return;
        context.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${target.nickname}님에게 대화를 요청했어요. 수락하면 바로 대화가 시작돼요. '
              '(${AppLimits.requestExpiry.inMinutes}분 안에 답이 없으면 자동으로 끝나요)',
            ),
          ),
        );
      case SendRequestResult.dailyLimit:
        if (!context.mounted) return;
        await showPlusPrompt(
          context,
          reason: '무료로는 하루 ${AppLimits.freeDailyRequests}번까지 요청할 수 있어요.',
        );
      case SendRequestResult.duplicate:
      case SendRequestResult.notCheckedIn:
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 상대 카드·보낸 요청·남은 횟수만 구독한다. 글자를 칠 때는 보내기 버튼만 다시 그린다.
    final spotId = ref.watch(mySpotIdProvider);
    final target = spotId == null
        ? null
        : ref.watch(
            feedProvider(
              spotId,
            ).select((l) => l.where((c) => c.uid == widget.userId).firstOrNull),
          );
    final pending = ref.watch(pendingToProvider(widget.userId));
    final leftToday =
        AppLimits.freeDailyRequests - ref.watch(sentTodayProvider);
    final plus = ref.watch(isPlusActiveProvider);

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
                            '· ${target.jobLabel}',
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
                      '이미 대화를 요청했어요',
                      style: AppTypography.supportingTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('“${pending.message}”', style: AppTypography.body),
                    const SizedBox(height: AppSpacing.xs),
                    _Waiting(
                      nickname: target.nickname,
                      expiresAt: pending.expiresAt,
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                '어떤 대화를 하고 싶어요?',
                style: AppTypography.supportingTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                maxLength: AppLimits.requestMessageMax,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '예) 저도 쉬는 중이에요! 10분만 얘기해요',
                ),
              ),
              if (!plus)
                Text(
                  leftToday > 0
                      ? '오늘 남은 무료 요청 $leftToday번'
                      : '오늘 무료 요청을 모두 썼어요',
                  style: AppTypography.caption,
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, _) => FilledButton(
                onPressed:
                    !_sending &&
                        pending == null &&
                        value.text.trim().length >= AppLimits.requestMessageMin
                    ? _send
                    : null,
                child: const Text('대화 요청하기'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${target.nickname}님이 수락하면 1:1 대화가 시작돼요.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// "OO님의 수락을 기다리는 중 · 남은 시간" — 시계만 구독
class _Waiting extends ConsumerWidget {
  const _Waiting({required this.nickname, required this.expiresAt});

  final String nickname;
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(
      clockProvider.select(
        (now) => TimeFormat.remaining(expiresAt.difference(now)),
      ),
    );
    return Text('$nickname님의 수락을 기다리는 중 · $left', style: AppTypography.caption);
  }
}
