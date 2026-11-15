import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';

/// 닉네임 + 직무 태그 입력 (US-002). 온보딩과 프로필 수정에서 같이 쓴다.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    required this.submitLabel,
    required this.onSubmit,
    this.header,
    this.initialNickname = '',
    this.initialJobTag,
    super.key,
  });

  final Widget? header;
  final String initialNickname;
  final JobTag? initialJobTag;
  final String submitLabel;
  final void Function(String nickname, JobTag jobTag) onSubmit;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late final _nickname = TextEditingController(text: widget.initialNickname);
  late JobTag? _jobTag = widget.initialJobTag;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  String? get _nicknameError {
    final n = _nickname.text.trim();
    if (n.isEmpty) return null;
    if (n.length < AppLimits.nicknameMin) {
      return '닉네임은 ${AppLimits.nicknameMin}자 이상이어야 해요';
    }
    if (n != widget.initialNickname &&
        ref.read(demoStoreProvider.notifier).isNicknameTaken(n)) {
      return '이미 쓰고 있는 닉네임이에요';
    }
    return null;
  }

  bool get _valid =>
      _nickname.text.trim().isNotEmpty &&
      _nicknameError == null &&
      _jobTag != null;

  @override
  Widget build(BuildContext context) {
    final error = _nicknameError;
    final n = _nickname.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              ?widget.header,
              Text(
                '닉네임',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nickname,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w500,
                ),
                maxLength: AppLimits.nicknameMax,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '실명 대신 불리고 싶은 이름',
                  errorText: error,
                  helperText: error == null && n.length >= AppLimits.nicknameMin
                      ? '사용할 수 있는 닉네임이에요'
                      : '${AppLimits.nicknameMin}~${AppLimits.nicknameMax}자',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '하는 일',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '카드에 닉네임과 함께 보여요. 1개만 고를 수 있어요.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tag in JobTag.values)
                    SelectChip(
                      label: tag.label,
                      selected: _jobTag == tag,
                      onTap: () => setState(() => _jobTag = tag),
                    ),
                ],
              ),
            ],
          ),
        ),
        BottomCta(
          child: FilledButton(
            onPressed: _valid
                ? () => widget.onSubmit(_nickname.text.trim(), _jobTag!)
                : null,
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}

/// 온보딩 단계 표시 "1 / 2"
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    required this.step,
    required this.total,
    required this.title,
    required this.description,
    super.key,
  });

  final int step;
  final int total;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= total; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: i == total ? 0 : AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.primary : AppColors.fill,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl - 8),
          Text(title, style: AppTypography.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
