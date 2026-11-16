import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/bind_logo.dart';
import '../../../core/widgets/google_sign_in_button.dart';
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
            // 위 여백 : 소개 : 사이 여백 : 카드 영역 비율로 세로 배치
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                children: [
                  const BindLogo(size: 32),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    '같은 공간에서\n같은 관심사로',
                    style: AppTypography.display,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '지금 있는 장소를 적고 주제 한 줄을 올리면\n같은 장소 사람과 대화를 나눌 수 있어요.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
            const Expanded(flex: 9, child: _CardPreview()),
            BottomCta(
              // Google 가이드: Google 버튼은 다른 로그인 버튼과 크기·무게가 비슷해야 한다.
              top: isIos
                  ? FilledButton.icon(
                      onPressed: _loading ? null : _signIn,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                        backgroundColor: AppColors.heading,
                        foregroundColor: AppColors.canvas,
                      ),
                      icon: const Icon(Icons.apple, size: 22),
                      label: const Text('Apple로 계속하기'),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GoogleSignInButton(onPressed: _signIn, loading: _loading),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '계속하면 이용약관·개인정보 처리방침에 동의하게 돼요.',
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
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(AppRadius.section),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _EmojiAvatar(emoji, index: i),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name · $job',
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

/// 소개용 일러스트 아바타(실제 사용자 사진이 아니다. 앱에서 프로필 사진은 받지 않는다)
class _EmojiAvatar extends StatelessWidget {
  const _EmojiAvatar(this.emoji, {required this.index});

  final String emoji;
  final int index;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final (bg, _) = AppColors.avatarTints[index % AppColors.avatarTints.length];
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: _size * 0.55, height: 1),
      ),
    );
  }
}
