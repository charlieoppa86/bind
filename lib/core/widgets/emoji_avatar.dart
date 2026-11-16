import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 소개용 일러스트 아바타(첫 화면·사용법 가이드).
/// 실제 사용자 사진이 아니다. 앱에서 프로필 사진은 받지 않는다(US-W05).
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar(
    this.emoji, {
    required this.index,
    this.size = 40,
    super.key,
  });

  final String emoji;

  /// 배경색 고르기용 순번
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, _) = AppColors.avatarTints[index % AppColors.avatarTints.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.55, height: 1)),
    );
  }
}

/// 소개용 주제 카드: 아바타 + "닉네임 · 하는 일" + 주제 한 줄
class IntroTopicCard extends StatelessWidget {
  const IntroTopicCard({
    required this.emoji,
    required this.index,
    required this.name,
    required this.job,
    required this.topic,
    this.trailing,
    this.footer,
    this.shadow = false,
    super.key,
  });

  final String emoji;
  final int index;
  final String name;
  final String job;
  final String topic;
  final Widget? trailing;

  /// 카드 아래쪽에 붙는 내용(예: 받은 신청 한 마디)
  final Widget? footer;

  /// 떠 있는 그림자(첫 화면처럼 겹쳐 놓을 때)
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.section),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiAvatar(emoji, index: index),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name · $job', style: AppTypography.caption),
                    const SizedBox(height: 2),
                    Text(
                      topic,
                      style: AppTypography.supportingTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          ?footer,
        ],
      ),
    );
  }
}
