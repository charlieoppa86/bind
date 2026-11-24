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
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/models/checkin.dart';
import '../../my/presentation/plus_prompt.dart';
import 'spot_feed_screen.dart' show GroupChatBadge;

/// 스팟 > 스팟 피드 > 대화 요청 (바텀시트, US-007)
///
/// 카드에 그룹 채팅이 열려 있으면(US-025) 위에 "그룹 채팅 참여하기"를 먼저 보여 주고,
/// 아래에서 1:1 채팅 요청도 고를 수 있다.
class ChatRequestSheet extends ConsumerStatefulWidget {
  const ChatRequestSheet({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ChatRequestSheet> createState() => _ChatRequestSheetState();
}

class _ChatRequestSheetState extends ConsumerState<ChatRequestSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _joining = false;

  Future<void> _joinGroup(Checkin target) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _joining = true);
    final GroupJoinResult result;
    final String? chatId;
    try {
      (result, chatId) = await ref
          .read(demoStoreProvider.notifier)
          .joinGroupChat(target);
    } catch (e) {
      debugPrint('[BIND] 그룹 채팅 참여 실패: $e');
      if (mounted) setState(() => _joining = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('들어가지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _joining = false);
    switch (result) {
      case GroupJoinResult.joined:
        router.pop();
        router.push(Routes.chatRoom(chatId!));
      case GroupJoinResult.full:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              '${AppLimits.groupChatMaxMembers}명이 다 차서 들어갈 수 없어요. '
              '1:1 채팅을 요청해 보세요.',
            ),
          ),
        );
      case GroupJoinResult.notCheckedIn:
      case GroupJoinResult.gone:
        messenger.showSnackBar(
          const SnackBar(content: Text('지금은 이 그룹 채팅에 들어갈 수 없어요.')),
        );
    }
  }

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
                          Flexible(
                            child: Text(
                              '· ${target.profileLabel}',
                              style: AppTypography.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (target.hasTrustBadge) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const TrustBadge(),
                          ],
                        ],
                      ),
                      Text(target.keywordLabel, style: AppTypography.caption),
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
            if (target.groupChatId case final groupId?) ...[
              _GroupJoinBox(
                chatId: groupId,
                count: target.groupMemberCount,
                busy: _joining,
                onJoin: () => _joinGroup(target),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
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
              Text(
                target.hasGroupChat
                    ? '${ChatType.direct.label}으로 이야기하고 싶다면'
                    : '어떤 대화를 하고 싶어요?',
                style: AppTypography.supportingTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                maxLength: AppLimits.requestMessageMax,
                // 그룹 참여 버튼이 키보드에 가리지 않도록 그룹이 있으면 바로 열지 않는다.
                autofocus: !target.hasGroupChat,
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
                child: Text(
                  target.hasGroupChat
                      ? '${ChatType.direct.label} 요청하기'
                      : '대화 요청하기',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${target.nickname}님이 수락하면 ${ChatType.direct.label}이 시작돼요.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드에 열린 그룹 채팅: 인원 + 참여(이미 들어가 있으면 방으로 가기)
class _GroupJoinBox extends ConsumerWidget {
  const _GroupJoinBox({
    required this.chatId,
    required this.count,
    required this.busy,
    required this.onJoin,
  });

  final String chatId;
  final int count;
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(isGroupMemberProvider(chatId));
    final full = !joined && count >= AppLimits.groupChatMaxMembers;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GroupChatBadge(chatId: chatId, count: count),
          const SizedBox(height: AppSpacing.xs),
          Text(
            joined
                ? '이미 들어가 있는 ${ChatType.group.label}이에요.'
                : '요청 없이 바로 들어가 같은 주제로 여럿이 이야기해요.',
            style: AppTypography.body.copyWith(color: AppColors.heading),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: busy || full
                ? null
                : joined
                ? () {
                    final router = GoRouter.of(context);
                    router.pop();
                    router.push(Routes.chatRoom(chatId));
                  }
                : onJoin,
            icon: const Icon(Icons.groups_rounded),
            label: Text(
              joined
                  ? '${ChatType.group.label}방으로 가기'
                  : full
                  ? '인원이 다 찼어요'
                  : '${ChatType.group.label} 참여하기',
            ),
          ),
        ],
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
