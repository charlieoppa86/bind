import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/constants/topic_content.dart';

/// 체크인 > 주제 설정 > 예시 주제 (바텀시트, US-014)
/// 선택한 예시 문자열을 pop 결과로 돌려준다.
class TopicExamplesSheet extends StatelessWidget {
  const TopicExamplesSheet({this.category, super.key});

  final TopicCategory? category;

  @override
  Widget build(BuildContext context) {
    final c = category ?? TopicCategory.other;
    final examples = (topicExamples[c] ?? const <String>[]).take(
      AppLimits.topicExamplesPerCategory,
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.label} 예시 주제', style: AppTypography.subtitle),
                const SizedBox(height: 2),
                const Text('고른 뒤에 자유롭게 고칠 수 있어요', style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final e in examples)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              title: Text(
                e,
                style: AppTypography.body.copyWith(color: AppColors.heading),
              ),
              trailing: const Icon(
                Icons.north_west,
                size: 16,
                color: AppColors.secondary,
              ),
              onTap: () => context.pop(e),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
