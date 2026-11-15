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
import '../../../data/models/chat.dart';
import '../../safety/presentation/safety_menu.dart';

/// 채팅 > 대화 목록 > 대화방 (US-009). 텍스트만 주고받는다.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    // TODO(firebase): chats/{chatId}/messages 추가 + 상대에게 FCM
    ref
        .read(demoStoreProvider.notifier)
        .sendMessage(widget.chatId, _input.text);
    _input.clear();
    setState(() {});
  }

  void _leave() {
    // US-017: 대화방을 나갈 때 평가를 한 번 묻는다.
    if (ref.read(demoStoreProvider.notifier).shouldAskReview(widget.chatId)) {
      context.push(Routes.chatReview(widget.chatId));
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final chat = db.chat(widget.chatId);
    if (chat == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.chat_bubble_outline,
          title: '사라진 대화예요',
          message: '대화는 시작하고 일정 기간이 지나면 사라져요.',
        ),
      );
    }
    final otherUid = chat.otherUid(DemoDb.myUid);
    final other = db.user(otherUid);
    final left = chat.leftUids.contains(otherUid) || (other?.deleted ?? false);
    final messages = db.messages[chat.id] ?? const <ChatMessage>[];

    if ((db.unread[chat.id] ?? 0) > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(demoStoreProvider.notifier).openChat(chat.id),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                left ? '떠난 사용자' : other?.nickname ?? '',
                style: AppTypography.supportingTitle,
              ),
              if (!left && other != null)
                Text(other.jobTag.label, style: AppTypography.caption),
            ],
          ),
          actions: [
            if (!left)
              SafetyMenuButton(
                targetUid: otherUid,
                source: ReportSource.chat,
                iconColor: AppColors.heading,
                onBlocked: () => context.go(Routes.chats),
              ),
          ],
        ),
        body: Column(
          children: [
            _RetentionBanner(chat: chat),
            Expanded(
              child: messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.waving_hand_outlined,
                      title: '대화가 열렸어요',
                      message: '먼저 인사하고, 지금 어디쯤 있는지 알려주세요.',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final index = messages.length - 1 - i;
                        final m = messages[index];
                        final prev = index > 0 ? messages[index - 1] : null;
                        final next = index < messages.length - 1
                            ? messages[index + 1]
                            : null;
                        final newDay =
                            prev == null || !_sameDay(prev.sentAt, m.sentAt);
                        final showTime =
                            next == null ||
                            next.senderUid != m.senderUid ||
                            next.sentAt.difference(m.sentAt).inMinutes >= 1;
                        return Column(
                          children: [
                            if (newDay) _DaySeparator(m.sentAt),
                            _Bubble(
                              message: m,
                              mine: m.senderUid == DemoDb.myUid,
                              showTime: showTime,
                              grouped:
                                  prev != null &&
                                  prev.senderUid == m.senderUid &&
                                  !newDay,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (left)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: AppColors.fill,
                child: SafeArea(
                  top: false,
                  child: Text(
                    '상대가 BIND를 떠나 더 이상 메시지를 보낼 수 없어요.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              _Composer(
                controller: _input,
                onSend: _send,
                onChanged: () => setState(() {}),
              ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _RetentionBanner extends StatelessWidget {
  const _RetentionBanner({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.fill,
      child: Row(
        children: [
          const Icon(
            Icons.auto_delete_outlined,
            size: 14,
            color: AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${AppLimits.chatRetention.inDays}일 뒤 대화가 사라집니다 · '
              '${TimeFormat.date(chat.expiresAt)}까지 보관',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(TimeFormat.fullDate(date), style: AppTypography.caption),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showTime,
    required this.grouped,
  });

  final ChatMessage message;
  final bool mine;
  final bool showTime;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final time = showTime
        ? Text(
            TimeFormat.clock(message.sentAt),
            style: AppTypography.caption.copyWith(fontSize: 11),
          )
        : const SizedBox.shrink();
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.fill,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.menu),
            topRight: const Radius.circular(AppRadius.menu),
            bottomLeft: Radius.circular(mine ? AppRadius.menu : 4),
            bottomRight: Radius.circular(mine ? 4 : AppRadius.menu),
          ),
        ),
        child: Text(
          message.text,
          style: AppTypography.body.copyWith(
            color: mine ? AppColors.onPrimary : AppColors.heading,
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: grouped ? 3 : AppSpacing.sm),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine
            ? [
                time,
                const SizedBox(width: AppSpacing.xs),
                bubble,
                const SizedBox(width: 2),
              ]
            : [
                const SizedBox(width: 2),
                bubble,
                const SizedBox(width: AppSpacing.xs),
                time,
              ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => canSend ? onSend() : null,
                  decoration: InputDecoration(
                    hintText: '메시지 보내기',
                    fillColor: AppColors.fill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filled(
                tooltip: '보내기',
                onPressed: canSend ? onSend : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.hairline,
                  foregroundColor: AppColors.onPrimary,
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
