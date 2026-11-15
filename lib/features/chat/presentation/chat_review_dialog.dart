import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../data/demo/demo_store.dart';

/// 채팅 > 대화방 > 대화 평가 (다이얼로그, US-017). 평가자는 비공개.
class ChatReviewDialog extends ConsumerWidget {
  const ChatReviewDialog({required this.chatId, super.key});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final chat = db.chat(chatId);
    final nickname = chat == null
        ? '상대'
        : db.user(chat.otherUid(DemoDb.myUid))?.nickname ?? '상대';

    void finish(ChatReviewRating? rating) {
      // TODO(firebase): rating != null 이면 chats/{chatId}/reviews/{myUid} 저장
      ref.read(demoStoreProvider.notifier).review(chatId, rating);
      context.go(Routes.chats);
      if (rating != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('평가를 남겼어요. 고마워요!')));
      }
    }

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$nickname님과의 대화는 어땠나요?', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '누가 어떤 평가를 남겼는지는 서로 볼 수 없어요.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _RatingButton(
                    icon: Icons.thumb_up_alt_outlined,
                    label: '좋았어요',
                    onTap: () => finish(ChatReviewRating.good),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RatingButton(
                    icon: Icons.sentiment_neutral_outlined,
                    label: '그저 그래요',
                    onTap: () => finish(ChatReviewRating.soso),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => finish(null),
              style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
              child: const Text('건너뛰기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.heading),
          ),
        ],
      ),
    );
  }
}
