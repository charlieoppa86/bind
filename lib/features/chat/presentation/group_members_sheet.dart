import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import '../../safety/presentation/safety_menu.dart';

/// 그룹 채팅방 > 참여자 (바텀시트, US-025)
///
/// 참여자마다 신고·차단(US-010)을 할 수 있고, 맨 아래에서 방을 나간다.
/// "나가기"를 누르면 시트가 `true`로 닫히고, 확인은 대화방이 묻는다.
class GroupMembersSheet extends ConsumerWidget {
  const GroupMembersSheet({required this.chatId, super.key});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider(chatId));
    if (chat == null) return const SizedBox.shrink();
    // 연 사람을 맨 위에, 나를 그다음에
    final members =
        [
          for (final u in chat.memberUids)
            if (!chat.leftUids.contains(u)) u,
        ]..sort(
          (a, b) => _rank(chat.ownerUid, a).compareTo(_rank(chat.ownerUid, b)),
        );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              '참여자 ${members.length}/${AppLimits.groupChatMaxMembers}명',
              style: AppTypography.title,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final uid in members)
                  _MemberRow(
                    uid: uid,
                    owner: uid == chat.ownerUid,
                    // 신고하며 차단하면 시트를 닫는다(차단한 사람의 메시지는 숨겨진다).
                    onBlocked: () => context.pop(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListRow(
            title: '${ChatType.group.label} 나가기',
            titleStyle: AppTypography.bodyLarge.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            showChevron: false,
            onTap: () => context.pop(true),
          ),
        ],
      ),
    );
  }

  static int _rank(String? owner, String uid) => uid == owner
      ? 0
      : uid == DemoDb.myUid
      ? 1
      : 2;
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.uid,
    required this.owner,
    required this.onBlocked,
  });

  final String uid;
  final bool owner;
  final VoidCallback onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (name, job) = ref.watch(
      userProvider(uid).select(
        (u) => (
          u?.nickname ?? '',
          u == null
              ? null
              : [
                  u.jobLabel,
                  u.demographicLabel,
                ].where((s) => s.isNotEmpty).join(' · '),
        ),
      ),
    );
    final me = uid == DemoDb.myUid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          InitialAvatar(name, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTypography.supportingTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (owner) ...const [
                      SizedBox(width: AppSpacing.xs + 2),
                      StatusPill('연 사람', tone: PillTone.active),
                    ],
                    if (me) ...const [
                      SizedBox(width: AppSpacing.xs + 2),
                      StatusPill('나'),
                    ],
                  ],
                ),
                if (job != null) Text(job, style: AppTypography.caption),
              ],
            ),
          ),
          if (!me)
            SafetyMenuButton(
              targetUid: uid,
              source: ReportSource.chat,
              onBlocked: onBlocked,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
