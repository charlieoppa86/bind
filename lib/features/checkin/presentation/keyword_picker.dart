import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';

/// 주제 키워드 고르기(그룹별 칩) + "기타"를 고르면 직접 입력칸.
/// 체크인 화면과 주제 수정·추가 화면이 같이 쓴다.
class KeywordPicker extends StatelessWidget {
  const KeywordPicker({
    required this.selected,
    required this.onSelected,
    required this.customController,
    this.customFocus,
    super.key,
  });

  final TopicCategory? selected;
  final ValueChanged<TopicCategory> onSelected;

  /// 기타 직접 입력
  final TextEditingController customController;
  final FocusNode? customFocus;

  @override
  Widget build(BuildContext context) {
    final isOther = selected == TopicCategory.other;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in KeywordGroup.values) ...[
          if (group.label.isNotEmpty) ...[
            Text(
              group.label,
              style: AppTypography.caption.copyWith(color: AppColors.tertiary),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: [
              for (final c in TopicCategory.values)
                if (c.group == group)
                  SelectChip(
                    label: c.label,
                    compact: true,
                    selected: selected == c,
                    onTap: () {
                      onSelected(c);
                      // 기타를 고르면 바로 직접 입력칸으로
                      if (c == TopicCategory.other) customFocus?.requestFocus();
                    },
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // 기타 → 직접 입력
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isOther
              ? TextField(
                  key: const Key('keyword-custom-field'),
                  controller: customController,
                  focusNode: customFocus,
                  maxLength: AppLimits.keywordCustomMax,
                  textInputAction: TextInputAction.done,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: '키워드를 직접 적어 주세요 (예: 사진)',
                    helperText: '카드에 이 키워드가 보여요',
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
