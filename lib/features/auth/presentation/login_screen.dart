import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/apple_sign_in_button.dart';
import '../../../core/widgets/bind_logo.dart';
import '../../../core/widgets/emoji_avatar.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../../../core/notice/in_app_notice.dart';
import '../../../data/account/account_repository.dart';
import '../../session/account_controller.dart';
import '../../../core/constants/brand.dart';

/// 인증 > 로그인 (US-001). Android: 구글 / iOS: 구글·애플
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// 로그인 수단. Apple은 iOS에서만 보인다.
enum _SignInMethod { google, apple }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 진행 중인 로그인(그동안 두 버튼 모두 막는다)
  _SignInMethod? _pending;

  Future<void> _signIn(_SignInMethod method) async {
    if (_pending != null) return;
    setState(() => _pending = method);
    final account = ref.read(accountProvider);
    try {
      await switch (method) {
        _SignInMethod.google => account.signIn(),
        _SignInMethod.apple => account.signInWithApple(),
      };
    } on NoGoogleAccountException {
      ref
          .read(inAppNoticeProvider.notifier)
          .show(
            const InAppNotice(
              '이 기기에 로그인된 Google 계정이 없어요. 설정 > 계정에서 Google 계정을 추가한 뒤 다시 시도해 주세요.',
            ),
          );
    } catch (e, st) {
      debugPrint('[BIND] 로그인 실패: $e\n$st');
      ref
          .read(inAppNoticeProvider.notifier)
          .show(const InAppNotice('로그인하지 못했어요. 잠시 후 다시 시도해 주세요.'));
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  /// 상황별 카드 3장을 균형 배치 위치에서 아래로 내리는 거리
  static const _cardsOffsetY = 30.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // 카드 미리보기는 화면 높이의 30%(최대 270)로 고정해,
            // 긴 화면에서 카드·로그인 영역이 아래로 처지지 않게 한다.
            final cardsHeight = (c.maxHeight * 0.3).clamp(0.0, 270.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 남는 높이는 위 3 : 소개-카드 사이 2 : 카드-로그인 사이 2 로 나눈다.
                // (카드-로그인 사이에는 Apple 버튼 자리가 이미 비어 있어 비율을 덜 준다)
                const Spacer(flex: 3),
                const _Intro(),
                const Spacer(flex: 2),
                // 카드만 아래로 살짝 내린다(다른 요소 위치는 그대로).
                Transform.translate(
                  offset: const Offset(0, _cardsOffsetY),
                  child: SizedBox(
                    height: cardsHeight,
                    child: const _CardPreview(),
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _LoginArea(
                    onGoogle: () => _signIn(_SignInMethod.google),
                    onApple: () => _signIn(_SignInMethod.apple),
                    pending: _pending,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 로고 + 슬로건 + 한 줄 문구
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        children: [
          // 첫 화면 로고는 기본(32)의 1.5배
          const BindLogo(size: 48),
          const SizedBox(height: AppSpacing.lg + 4),
          const Text(
            Brand.sloganTwoLines,
            style: AppTypography.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Brand.startCall,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.secondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 로그인 버튼 영역. 버튼 두 개 높이를 미리 잡아 두고 위부터 채운다.
/// Google 버튼은 두 플랫폼 모두 같은 자리(위)에 있고, iOS는 그 아래에 Apple 버튼이 온다.
/// Android는 Apple 자리가 비어 있어 화면 배치가 iOS와 같다.
class _LoginArea extends StatelessWidget {
  const _LoginArea({
    required this.onGoogle,
    required this.onApple,
    required this.pending,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final _SignInMethod? pending;

  /// 로그인 버튼 높이(GoogleSignInButton과 같다)
  static const _buttonHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _buttonHeight * 2 + AppSpacing.sm + 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GoogleSignInButton(
                onPressed: pending == null ? onGoogle : null,
                loading: pending == _SignInMethod.google,
              ),
              // App Store 규정: Google 로그인이 있으면 Apple 로그인도 같은 크기로 둔다.
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: AppSpacing.sm + 4),
                AppleSignInButton(
                  onPressed: pending == null ? onApple : null,
                  loading: pending == _SignInMethod.apple,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '계속하면 이용약관·개인정보 처리방침에 동의하게 돼요.',
          style: AppTypography.caption.copyWith(color: AppColors.tertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 서비스를 한눈에 보여주는 주제 카드 미리보기
class _CardPreview extends StatelessWidget {
  const _CardPreview();

  @override
  Widget build(BuildContext context) {
    // (닉네임, 하는 일, 주제, 아바타, 기울기, 가로 위치)
    final cards = [
      ('도윤', JobTag.developer.label, 'AI 같이 공부해요', '🧑‍💻', -0.03, 0.0),
      ('하린', JobTag.freelancer.label, '가벼운 스몰톡이 하고 싶어요', '🙋‍♀️', 0.025, 28.0),
      ('재현', JobTag.designer.label, '이직 고민이 있어요', '🧑‍💼', -0.015, 6.0),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        if (h < 180) return const SizedBox.shrink();
        // 카드 3장 묶음을 영역 가운데에 둔다.
        const cardHeight = 72.0;
        final step = (h - cardHeight) / 2 > 96 ? 96.0 : (h - cardHeight) / 2;
        final top = (h - (step * 2 + cardHeight)) / 2;
        return Stack(
          children: [
            for (final (i, (name, job, topic, emoji, angle, dx))
                in cards.indexed)
              Positioned(
                left: AppSpacing.page + dx,
                right: AppSpacing.page + 28 - dx,
                top: top + i * step,
                child: Transform.rotate(
                  angle: angle,
                  child: IntroTopicCard(
                    emoji: emoji,
                    index: i,
                    name: name,
                    job: job,
                    topic: topic,
                    shadow: true,
                    trailing: i == 0
                        ? const StatusPill('대화 중', tone: PillTone.active)
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
