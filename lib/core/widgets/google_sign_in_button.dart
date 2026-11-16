import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Google 로그인 버튼 — Google 브랜드 가이드라인(Dark 테마, 알약 모양) 그대로.
/// https://developers.google.com/identity/branding-guidelines
///
/// - 바탕 #131314, 안쪽 1px 테두리 #8E918F, 글자 #E3E3E3
/// - 공식 표준색 "G" 로고(에셋에서 잘라낸 그대로, 재채색·변형 금지), 20px
/// - 여백: Android 왼쪽 12 / 로고 뒤 10 / 오른쪽 12, iOS 16 / 12 / 16
/// - 글자 14/20 Medium. 가이드의 Google Sans는 한글이 없어 앱 글꼴(Pretendard)을 쓴다.
/// - 문구는 Google 계정을 새로 만드는 게 아니라 Google 계정으로 이 앱에 들어간다는 뜻이어야 한다.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.loading = false,
    this.label = 'Google로 로그인',
    super.key,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  static const _logoSize = 20.0;
  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final (outer, gap) = isIos ? (16.0, 12.0) : (12.0, 10.0);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.googleDarkFill,
        shape: const StadiumBorder(
          side: BorderSide(
            color: AppColors.googleDarkStroke,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          overlayColor: WidgetStatePropertyAll(
            AppColors.googleDarkText.withValues(alpha: 0.08),
          ),
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: outer),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google_g_dark.png',
                    width: _logoSize,
                    height: _logoSize,
                    excludeFromSemantics: true,
                  ),
                  SizedBox(width: gap),
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.googleDarkText,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.googleDarkText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
