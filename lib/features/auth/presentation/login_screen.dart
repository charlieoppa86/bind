import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/bind_logo.dart';
import '../../../data/demo/demo_store.dart';

/// 인증 > 로그인 (US-001). Android: 구글 / iOS: 구글·애플
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    // TODO(auth): google_sign_in / sign_in_with_apple + FirebaseAuth
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    ref.read(demoStoreProvider.notifier).signIn();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BindLogo(size: 28),
              ),
            ),
            PageHeader(
              title: '지금 여기,\n같은 주제의 사람과\n바로 대화해요',
              description:
                  '반경 ${AppLimits.roomRadiusMeters.round()}m 안에 있는 사람의 주제 한 줄을 보고\n수락받으면 1:1 대화가 열려요.',
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                0,
              ),
            ),
            const Expanded(child: _CardPreview()),
            BottomCta(
              top: isIos
                  ? FilledButton.icon(
                      onPressed: _loading ? null : _signIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.heading,
                      ),
                      icon: const Icon(Icons.apple, size: 22),
                      label: const Text('Apple로 계속하기'),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  isIos
                      ? OutlinedButton(
                          onPressed: _loading ? null : _signIn,
                          child: _GoogleLabel(loading: _loading),
                        )
                      : FilledButton(
                          onPressed: _loading ? null : _signIn,
                          child: _GoogleLabel(
                            loading: _loading,
                            onPrimary: true,
                          ),
                        ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '계속하면 이용약관·개인정보 처리방침에 동의하게 돼요. 위치는 주변 방을 찾을 때만 쓰고 저장하지 않아요.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.tertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLabel extends StatelessWidget {
  const _GoogleLabel({required this.loading, this.onPrimary = false});

  final bool loading;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final color = onPrimary ? AppColors.onPrimary : AppColors.heading;
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.tertiary,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            shape: BoxShape.circle,
          ),
          child: Text(
            'G',
            style: AppTypography.supportingTitle.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('Google로 시작하기', style: TextStyle(color: color)),
      ],
    );
  }
}

/// 서비스를 한눈에 보여주는 주제 카드 미리보기
class _CardPreview extends StatelessWidget {
  const _CardPreview();

  @override
  Widget build(BuildContext context) {
    const cards = [
      ('도윤', JobTag.developer, 'Riverpod 3 마이그레이션 해보신 분?', -0.03, 0.0),
      ('하린', JobTag.marketer, '1인 마케터 예산 배분 고민', 0.025, 28.0),
      ('재현', JobTag.founder, 'MVP 검증 어떻게 하셨어요', -0.015, 6.0),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        if (h < 180) return const SizedBox.shrink();
        return Stack(
          children: [
            for (final (i, (name, job, topic, angle, dx)) in cards.indexed)
              Positioned(
                left: AppSpacing.page + dx,
                right: AppSpacing.page + 28 - dx,
                top: h * 0.12 + i * (h * 0.24),
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadius.section),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.heading.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        InitialAvatar(name, size: 36),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name · ${job.label}',
                                style: AppTypography.caption,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                topic,
                                style: AppTypography.supportingTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (i == 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const StatusPill('대화 중', tone: PillTone.active),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
