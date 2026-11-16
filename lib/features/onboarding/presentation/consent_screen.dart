import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/topic_content.dart';
import '../../../core/widgets/app_widgets.dart';
import 'profile_form.dart';
import '../../../core/notice/in_app_notice.dart';
import '../../../data/account/account_repository.dart';
import '../../session/account_controller.dart';

/// 인증 > 온보딩 > 연령·규칙 동의 (US-003)
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool? _isAdult;
  late final List<bool> _agreed = List.filled(communityRules.length, false);

  bool get _allAgreed => _agreed.every((a) => a);

  bool _saving = false;

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final notice = ref.read(inAppNoticeProvider.notifier);
    try {
      await ref.read(accountProvider).completeOnboarding();
      if (mounted) context.go(Routes.onboardingGuide);
    } on NicknameTakenException {
      // 그 사이 다른 사람이 같은 닉네임으로 가입했다 → 닉네임 다시 정하기
      notice.show(const InAppNotice('방금 다른 분이 같은 닉네임을 가져갔어요. 다른 닉네임을 골라주세요.'));
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[BIND] 가입 완료 실패: $e');
      notice.show(const InAppNotice('저장하지 못했어요. 잠시 후 다시 시도해 주세요.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
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
                const OnboardingStep(
                  step: 2,
                  total: 2,
                  title: '안전한 대화를 위해\n확인해 주세요',
                  description: '모두가 같은 규칙에 동의한 사람들이에요.',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AgeOption(
                        label: '만 ${AppLimits.minimumAge}세 이상',
                        selected: _isAdult == true,
                        onTap: () => setState(() => _isAdult = true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _AgeOption(
                        label: '만 ${AppLimits.minimumAge}세 미만',
                        selected: _isAdult == false,
                        onTap: () => setState(() => _isAdult = false),
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_isAdult) {
                    null => const SizedBox.shrink(),
                    false => Padding(
                      key: const ValueKey('minor'),
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.circular(
                            AppRadius.section,
                          ),
                        ),
                        child: const Text(
                          'BIND는 만 ${AppLimits.minimumAge}세 이상만 이용할 수 있어요.\n'
                          '낯선 사람과의 1:1 대화로부터 보호하기 위해 가입을 진행할 수 없어요.',
                          style: AppTypography.bodyLarge,
                        ),
                      ),
                    ),
                    true => Padding(
                      key: const ValueKey('rules'),
                      padding: const EdgeInsets.only(top: AppSpacing.xl - 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Pressable(
                            onTap: () => setState(
                              () => _agreed.fillRange(
                                0,
                                _agreed.length,
                                !_allAgreed,
                              ),
                            ),
                            haptic: true,
                            borderRadius: AppRadius.section,
                            color: _allAgreed
                                ? AppColors.primarySoft
                                : AppColors.fill,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  _CheckMark(checked: _allAgreed, size: 26),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      '이용 규칙에 모두 동의해요',
                                      style: AppTypography.subtitle.copyWith(
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final (i, rule) in communityRules.indexed)
                            Pressable(
                              onTap: () =>
                                  setState(() => _agreed[i] = !_agreed[i]),
                              borderRadius: AppRadius.card,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md,
                                ),
                                child: Row(
                                  children: [
                                    _CheckMark(
                                      checked: _agreed[i],
                                      size: 22,
                                      plain: true,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        rule,
                                        style: AppTypography.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  },
                ),
              ],
            ),
          ),
          BottomCta(
            child: _isAdult == false
                ? OutlinedButton(
                    onPressed: () => ref.read(accountProvider).signOut(),
                    child: const Text('처음으로 돌아가기'),
                  )
                : FilledButton(
                    onPressed: _isAdult == true && _allAgreed && !_saving
                        ? _complete
                        : null,
                    child: const Text('동의하고 가입 완료'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgeOption extends StatelessWidget {
  const _AgeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: AppRadius.section,
      color: selected ? AppColors.primarySoft : AppColors.fill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.section),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          '$label이에요',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.body,
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({
    required this.checked,
    required this.size,
    this.plain = false,
  });

  final bool checked;
  final double size;

  /// 동그라미 없이 체크만(개별 항목)
  final bool plain;

  @override
  Widget build(BuildContext context) {
    if (plain) {
      return Icon(
        Icons.check_rounded,
        size: size,
        color: checked ? AppColors.primary : AppColors.tertiary,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : AppColors.canvas,
        shape: BoxShape.circle,
        border: checked
            ? null
            : Border.all(color: AppColors.tertiary, width: 1.5),
      ),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.7,
        color: AppColors.onPrimary,
      ),
    );
  }
}
