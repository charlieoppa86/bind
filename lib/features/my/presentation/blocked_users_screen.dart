import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';

/// 마이 > 마이 > 차단 목록
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(demoStoreProvider).blocks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      backgroundColor: blocks.isEmpty
          ? AppColors.canvas
          : AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: blocks.isEmpty
            ? AppColors.canvas
            : AppColors.groupedBackground,
        title: const Text('차단 목록'),
      ),
      body: blocks.isEmpty
          ? const EmptyState(
              icon: Icons.block_outlined,
              title: '차단한 사용자가 없어요',
              message: '카드나 대화방의 ⋮ 메뉴에서 차단할 수 있어요.',
            )
          : ListView(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              children: [
                for (final b in blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        leading: InitialAvatar(b.targetNickname),
                        title: Text(
                          b.targetNickname,
                          style: AppTypography.supportingTitle,
                        ),
                        subtitle: Text(
                          '${TimeFormat.date(b.createdAt)} 차단',
                          style: AppTypography.caption,
                        ),
                        trailing: OutlinedButton(
                          onPressed: () {
                            // TODO(firebase): users/{me}/blocks/{uid} 삭제
                            ref
                                .read(demoStoreProvider.notifier)
                                .unblock(b.targetUid);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${b.targetNickname}님 차단을 해제했어요'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            textStyle: AppTypography.body,
                          ),
                          child: const Text('해제'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
