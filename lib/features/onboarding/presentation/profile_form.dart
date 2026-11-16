import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/account/account_repository.dart';
import '../../session/account_controller.dart';

/// 닉네임 + 직무 태그 입력 (US-002). 온보딩과 프로필 수정에서 같이 쓴다.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    required this.submitLabel,
    required this.onSubmit,
    this.header,
    this.initialNickname = '',
    this.initialJobTag,
    this.initialJobCustom,
    super.key,
  });

  final Widget? header;
  final String initialNickname;
  final JobTag? initialJobTag;
  final String? initialJobCustom;
  final String submitLabel;

  /// [jobCustom]은 기타를 골랐을 때만 값이 있다.
  /// 저장 중 닉네임을 다른 사람이 가져가면 [NicknameTakenException]을 던진다.
  final FutureOr<void> Function(
    String nickname,
    JobTag jobTag,
    String? jobCustom,
  )
  onSubmit;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late final _nickname = TextEditingController(text: widget.initialNickname);
  late JobTag? _jobTag = widget.initialJobTag;
  late final _jobCustom = TextEditingController(text: widget.initialJobCustom);
  final _jobCustomFocus = FocusNode();

  bool get _isOther => _jobTag == JobTag.other;

  void _selectJob(JobTag tag) {
    setState(() => _jobTag = tag);
    // 기타를 고르면 바로 직접 입력칸으로
    if (tag == JobTag.other) _jobCustomFocus.requestFocus();
  }

  @override
  void dispose() {
    _jobCustom.dispose();
    _jobCustomFocus.dispose();
    _nickname.dispose();
    super.dispose();
  }

  String? get _nicknameError {
    final n = _nickname.text.trim();
    if (n.isEmpty) return null;
    if (n.length < AppLimits.nicknameMin) {
      return '닉네임은 ${AppLimits.nicknameMin}자 이상이어야 해요';
    }
    if (_takenNickname != null &&
        nicknameKey(n) == nicknameKey(_takenNickname!)) {
      return '이미 쓰고 있는 닉네임이에요';
    }
    return null;
  }

  /// 서버에서 이미 쓰고 있다고 확인된 닉네임
  String? _takenNickname;
  bool _submitting = false;

  /// 닉네임 중복은 저장 버튼을 누를 때 서버(닉네임 예약)에 물어본다.
  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    setState(() => _submitting = true);
    try {
      final changed =
          nicknameKey(nickname) != nicknameKey(widget.initialNickname);
      if (changed &&
          await ref.read(accountProvider).isNicknameTaken(nickname)) {
        if (mounted) setState(() => _takenNickname = nickname);
        return;
      }
      await widget.onSubmit(
        nickname,
        _jobTag!,
        _isOther ? _jobCustom.text.trim() : null,
      );
    } on NicknameTakenException {
      if (mounted) setState(() => _takenNickname = nickname);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _valid =>
      _nickname.text.trim().isNotEmpty &&
      _nicknameError == null &&
      _jobTag != null &&
      (!_isOther || _jobCustom.text.trim().isNotEmpty);

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
                '카드에 닉네임과 함께 보여요. 지금 나를 가장 잘 나타내는 하나를 골라요.',
                style: AppTypography.caption,
              ),
              for (final group in JobTagGroup.values) ...[
                const SizedBox(height: AppSpacing.md),
                if (group.label.isNotEmpty) ...[
                  Text(
                    group.label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.tertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                ],
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    for (final tag in JobTag.values)
                      if (tag.group == group)
                        SelectChip(
                          label: tag.label,
                          compact: true,
                          selected: _jobTag == tag,
                          onTap: () => _selectJob(tag),
                        ),
                  ],
                ),
              ],
              // 기타 → 직접 입력
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _isOther
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: TextField(
                          key: const Key('job-custom-field'),
                          controller: _jobCustom,
                          focusNode: _jobCustomFocus,
                          maxLength: AppLimits.jobCustomMax,
                          textInputAction: TextInputAction.done,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.heading,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: '하는 일을 직접 적어 주세요 (예: 바리스타)',
                            helperText: '카드에 이 글자가 보여요',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        BottomCta(
          child: FilledButton(
            onPressed: _valid && !_submitting ? _submit : null,
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
