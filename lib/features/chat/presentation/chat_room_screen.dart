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
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/live/live_sync.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/models/chat.dart';
import '../../safety/presentation/safety_menu.dart';
import 'group_members_sheet.dart';

/// 대화방 상대 정보: (상대 uid, 상대가 떠났는지). 대화방이 없으면 null.
final _roomPeerProvider = Provider.autoDispose.family<(String, bool)?, String>((
  ref,
  chatId,
) {
  final chat = ref.watch(chatProvider(chatId));
  if (chat == null) return null;
  final otherUid = chat.otherUid(DemoDb.myUid);
  final deleted = ref.watch(
    userProvider(otherUid).select((u) => u?.deleted ?? false),
  );
  return (otherUid, chat.leftUids.contains(otherUid) || deleted);
});

/// 채팅 > 대화 목록 > 대화방 (US-009 1:1, US-025 그룹). 텍스트만 주고받는다.
///
/// 1:1 화면은 "상대가 누구이고 떠났는지"만 구독한다. 새 메시지가 오면 메시지 목록만,
/// 입력 중에는 입력창의 보내기 버튼만 다시 그린다. 그룹 채팅은 [_GroupRoom].
class ChatRoomScreen extends ConsumerWidget {
  const ChatRoomScreen({required this.chatId, super.key});

  final String chatId;

  void _leave(BuildContext context, WidgetRef ref) {
    // US-017: 대화방을 나갈 때 평가를 한 번 묻는다.
    if (ref.read(demoStoreProvider.notifier).shouldAskReview(chatId)) {
      context.push(Routes.chatReview(chatId));
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 방 종류는 바뀌지 않는다. 내가 나간 그룹은 사라진 대화로 본다.
    final kind = ref.watch(
      chatProvider(chatId).select(
        (c) => c == null
            ? null
            : c.isGroup && !c.memberUids.contains(DemoDb.myUid)
            ? null
            : c.type,
      ),
    );
    if (kind == ChatType.group) return _GroupRoom(chatId: chatId);
    final peer = kind == null ? null : ref.watch(_roomPeerProvider(chatId));
    if (peer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.chat_bubble_outline,
          title: '볼 수 없는 대화예요',
          message: '나간 그룹 채팅이거나 더 이상 없는 대화예요.',
        ),
      );
    }
    final (otherUid, left) = peer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _RoomTitle(otherUid: otherUid, left: left),
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
            _ReadMarker(chatId),
            Expanded(child: _MessageList(chatId)),
            if (left) const _LeftNotice() else _Composer(chatId: chatId),
          ],
        ),
      ),
    );
  }
}

class _RoomTitle extends ConsumerWidget {
  const _RoomTitle({required this.otherUid, required this.left});

  final String otherUid;
  final bool left;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (left) {
      return const Text('떠난 사용자', style: AppTypography.supportingTitle);
    }
    final (name, job) = ref.watch(
      userProvider(otherUid).select((u) => (u?.nickname ?? '', u?.jobLabel)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppTypography.supportingTitle),
        Text(
          [ChatType.direct.label, ?job].join(' · '),
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

/// 그룹 채팅방(US-025): 방 이름(주제)·인원, 참여자 시트(신고·차단·나가기).
/// 1:1과 달리 나갈 때 평가를 묻지 않고, 누가 떠나도 남은 사람끼리 이어간다.
class _GroupRoom extends ConsumerWidget {
  const _GroupRoom({required this.chatId});

  final String chatId;

  Future<void> _openMembers(BuildContext context, WidgetRef ref) async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GroupMembersSheet(chatId: chatId),
    );
    if (leave != true || !context.mounted) return;
    final ok = await showConfirm(
      context,
      title: '${ChatType.group.label}에서 나갈까요?',
      message: '나가면 이 대화가 목록에서 사라져요.\n카드가 남아 있으면 다시 들어올 수 있어요.',
      confirmLabel: '나가기',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    ref.read(demoStoreProvider.notifier).leaveGroupChat(chatId);
    context.go(Routes.chats);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _GroupTitle(chatId),
        actions: [
          IconButton(
            tooltip: '참여자',
            onPressed: () => _openMembers(context, ref),
            icon: const Icon(Icons.groups_outlined, color: AppColors.heading),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _ReadMarker(chatId),
          Expanded(child: _MessageList(chatId)),
          _Composer(chatId: chatId),
        ],
      ),
    );
  }
}

class _GroupTitle extends ConsumerWidget {
  const _GroupTitle(this.chatId);

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, count) = ref.watch(
      chatProvider(chatId).select(
        (c) => (c?.title ?? ChatType.group.label, c?.activeMemberCount ?? 0),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.supportingTitle,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${ChatType.group.label} · $count명',
          style: AppTypography.caption.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

/// 메시지 목록. 이 방의 메시지가 바뀔 때만 다시 그린다.
class _MessageList extends ConsumerWidget {
  const _MessageList(this.chatId);

  final String chatId;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 실제 모드: 이 방을 보는 동안만 메시지를 실시간으로 받는다.
    ref.watch(chatMessagesSyncProvider(chatId));
    final group = ref.watch(
      chatProvider(chatId).select((c) => c?.isGroup ?? false),
    );
    final all = ref.watch(messagesProvider(chatId));
    // 그룹 채팅: 내가 차단한 사람의 메시지는 숨긴다(1:1은 방 자체가 숨겨진다).
    final blocked = group
        ? ref.watch(
            blocksProvider.select((l) => {for (final b in l) b.targetUid}),
          )
        : const <String>{};
    final messages = blocked.isEmpty
        ? all
        : [
            for (final m in all)
              if (!blocked.contains(m.senderUid)) m,
          ];
    if (messages.isEmpty) {
      return EmptyState(
        icon: group ? Icons.groups_outlined : Icons.waving_hand_outlined,
        title: group ? '${ChatType.group.label}이 열렸어요' : '대화가 열렸어요',
        message: group
            ? '같은 장소 사람들이 들어오면 함께 이야기할 수 있어요. 먼저 인사를 남겨 보세요.'
            : '먼저 인사하고, 지금 어디쯤 있는지 알려주세요.',
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      // 맨 위(역순 목록의 마지막)에 시작 안내 한 줄
      itemCount: messages.length + 1,
      itemBuilder: (_, i) {
        if (i == messages.length) return _StartedNote(group: group);
        final index = messages.length - 1 - i;
        final m = messages[index];
        final prev = index > 0 ? messages[index - 1] : null;
        final next = index < messages.length - 1 ? messages[index + 1] : null;
        final newDay = prev == null || !_sameDay(prev.sentAt, m.sentAt);
        final showTime =
            next == null ||
            next.senderUid != m.senderUid ||
            next.sentAt.difference(m.sentAt).inMinutes >= 1;
        return Column(
          key: ValueKey(m.id),
          children: [
            if (newDay) _DaySeparator(m.sentAt),
            _Bubble(
              message: m,
              mine: m.senderUid == DemoDb.myUid,
              showTime: showTime,
              grouped: prev != null && prev.senderUid == m.senderUid && !newDay,
              showSender: group,
            ),
          ],
        );
      },
    );
  }
}

/// 보이지 않는 위젯: 보고 있는 동안 안 읽은 메시지가 생기면 바로 읽음 처리한다.
class _ReadMarker extends ConsumerWidget {
  const _ReadMarker(this.chatId);

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadProvider(chatId));
    if (unread > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(demoStoreProvider.notifier).openChat(chatId),
      );
    }
    return const SizedBox.shrink();
  }
}

class _LeftNotice extends StatelessWidget {
  const _LeftNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.fill,
      child: SafeArea(
        top: false,
        child: Text(
          '상대가 BIND를 떠나 더 이상 메시지를 보낼 수 없어요.',
          style: AppTypography.body.copyWith(color: AppColors.secondary),
          textAlign: TextAlign.center,
        ),
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
    this.showSender = false,
  });

  final ChatMessage message;
  final bool mine;
  final bool showTime;
  final bool grouped;

  /// 그룹 채팅: 다른 사람이 이어서 보낸 메시지의 첫 말풍선 위에 이름을 단다.
  final bool showSender;

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
    final row = Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
    );
    if (showSender && !mine && !grouped) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SenderName(message.senderUid),
            const SizedBox(height: 4),
            row,
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: grouped ? 3 : AppSpacing.sm),
      child: row,
    );
  }
}

/// 그룹 채팅 말풍선 위 보낸 사람 이름(탈퇴했으면 "떠난 사용자")
class _SenderName extends ConsumerWidget {
  const _SenderName(this.uid);

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(
      userProvider(uid)
          .select((u) => u == null || u.deleted ? '떠난 사용자' : u.nickname),
    );
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        name,
        style: AppTypography.caption.copyWith(color: AppColors.secondary),
      ),
    );
  }
}

/// 입력창. 글자를 칠 때 화면 전체가 아니라 보내기 버튼만 다시 그린다.
class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.chatId});

  final String chatId;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (_input.text.trim().isEmpty) return;
    // TODO(firebase): chats/{chatId}/messages 추가 + 상대에게 FCM
    ref
        .read(demoStoreProvider.notifier)
        .sendMessage(widget.chatId, _input.text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
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
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: AppLimits.chatMessageMax,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '메시지 보내기',
                    counterText: '',
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (_, value, _) => IconButton.filled(
                  tooltip: '보내기',
                  onPressed: value.text.trim().isEmpty ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.hairline,
                    foregroundColor: AppColors.onPrimary,
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 대화방 맨 위: 어떻게 시작된 대화인지 안내
class _StartedNote extends StatelessWidget {
  const _StartedNote({required this.group});

  final bool group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            group
                ? '체크인한 주제로 ${ChatType.group.label}이 열렸어요'
                : '대화 요청이 수락되어 ${ChatType.direct.label}이 시작됐어요',
            style: AppTypography.caption.copyWith(color: AppColors.secondary),
          ),
        ),
      ),
    );
  }
}
