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
import '../../../data/demo/demo_store.dart';
import '../../my/presentation/plus_prompt.dart';
import 'spot_feed_screen.dart' show GroupChatBadge;

/// 스팟 > 스팟 피드 > 내 체크인 (US-011)
class MyCheckinScreen extends ConsumerWidget {
  const MyCheckinScreen({super.key});

  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirm(
      context,
      title: '체크아웃할까요?',
      message: '내 카드가 바로 목록에서 사라져요.\n이미 열린 대화방은 그대로 남아요.',
      confirmLabel: '체크아웃',
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // TODO(firebase): checkins/{id}.checkedOutAt 기록
    ref.read(demoStoreProvider.notifier).checkOut();
    // 마이 탭에서 push로 들어온 경우 라우터 가드는 /my 기준으로만 검사하므로 직접 이동한다.
    router.go(Routes.checkinSpots);
    messenger.showSnackBar(
      const SnackBar(content: Text('체크아웃했어요. 다음에 또 만나요!')),
    );
  }

  void _addTopic(BuildContext context, int count, int limit, bool isPlus) {
    if (count < limit) {
      context.push(Routes.topicSetup(add: true));
    } else if (!isPlus) {
      showPlusPrompt(
        context,
        reason: '무료로는 주제를 ${AppLimits.freeActiveTopics}개까지 올릴 수 있어요.',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주제는 최대 ${AppLimits.plusActiveTopics}개까지 올릴 수 있어요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myCheckinsProvider);
    final topicLimit = ref.watch(topicLimitProvider);
    if (mine.isEmpty) {
      // 체크아웃된 경우: 이 화면을 떠난다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.checkinSpots);
      });
      return const Scaffold();
    }
    final first = mine.first;

    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: AppColors.groupedBackground,
        title: const Text('내 체크인'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.xl,
              ),
              children: [
                _PlaceCard(spotId: first.spotId, startedAt: first.startedAt),
                SectionLabel(
                  '내 주제 ${mine.length}/$topicLimit',
                  trailing: TextButton.icon(
                    onPressed: () => _addTopic(
                      context,
                      mine.length,
                      topicLimit,
                      ref.read(isPlusActiveProvider),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('주제 추가'),
                  ),
                ),
                for (final c in mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SectionCard(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.nickname} · ${c.profileLabel} · ${c.keywordLabel}',
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.topic,
                                  style: AppTypography.title.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                                if (c.groupChatId case final groupId?) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GroupChatBadge(
                                          chatId: groupId,
                                          count: c.groupMemberCount,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.push(
                                          Routes.chatRoom(groupId),
                                        ),
                                        child: const Text('들어가기'),
                                      ),
                                    ],
                                  ),
                                ] else if (c.openGroupChat) ...[
                                  // 실제 모드: 서버가 방을 만드는 동안
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    '${ChatType.group.label}을 여는 중이에요…',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '주제 수정',
                            onPressed: () =>
                                context.push(Routes.topicSetup(editId: c.id)),
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: AppColors.secondary,
                            ),
                          ),
                          if (mine.length > 1)
                            IconButton(
                              tooltip: '주제 내리기',
                              onPressed: () => ref
                                  .read(demoStoreProvider.notifier)
                                  .removeTopic(c.id),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: AppColors.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: Text(
                    '같은 장소 사람들에게는 닉네임·하는 일·연령대·성별·주제가 보여요.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          BottomCta(
            background: AppColors.groupedBackground,
            child: FilledButton(
              onPressed: () => _checkOut(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.heading,
                foregroundColor: AppColors.canvas,
              ),
              child: const Text('체크아웃'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 장소 이름 + 같은 장소 인원(인원 수가 바뀌면 이 카드만 다시 그린다)
class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({required this.spotId, required this.startedAt});

  final String spotId;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(spotProvider(spotId).select((s) => s?.name ?? ''));
    final others = ref.watch(headcountProvider(spotId)) - 1;
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetaLabel(
            '${TimeFormat.clock(startedAt)}부터 체크인 중',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(name, style: AppTypography.display),
          const SizedBox(height: AppSpacing.xs),
          Text(
            others > 0 ? '나 말고 $others명이 같은 장소에 있어요' : '아직 같은 장소에 다른 사람이 없어요',
            style: AppTypography.body.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
