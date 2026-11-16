import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    // TODO(auth): iOS는 sign_in_with_apple도 추가
    setState(() => _loading = true);
    try {
      await ref.read(accountProvider).signIn();
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
      if (mounted) setState(() => _loading = false);
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
                // 남는 높이는 위 3 : 소개-카드 사이 2 : 카드-로그인 사이 3 으로 나눈다.
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
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _LoginArea(onGoogle: _signIn, loading: _loading),
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
          const BindLogo(size: 32),
          const SizedBox(height: AppSpacing.lg),
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

/// 로그인 버튼 영역. 버튼 두 개(Apple + Google) 높이를 미리 잡아 두고 아래부터 채운다.
/// Apple 로그인을 붙이면 Google 버튼 위 빈 자리에 들어가서 화면 배치가 바뀌지 않는다.
class _LoginArea extends StatelessWidget {
  const _LoginArea({required this.onGoogle, required this.loading});

  final VoidCallback onGoogle;
  final bool loading;

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
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TODO(auth): Apple 로그인(sign_in_with_apple + Firebase Auth)을 붙이면
              // 여기에 "Apple로 계속하기" 버튼을 넣는다. Google 가이드에 따라 두 버튼은
              // 크기·무게가 같아야 한다. iOS 출시에는 Apple 로그인이 필수다.
              GoogleSignInButton(onPressed: onGoogle, loading: loading),
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
