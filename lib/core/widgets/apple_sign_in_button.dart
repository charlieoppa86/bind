import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Apple 로그인 버튼 — Apple 휴먼 인터페이스 가이드라인의 White 스타일.
/// https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
///
/// - 어두운 바탕에는 흰 버튼(검은 로고·글자)을 쓴다.
/// - Google 버튼과 같은 크기·모양(높이 48 알약)으로 둔다. 다른 로그인보다 작거나
///   눈에 덜 띄면 안 된다.
/// - 문구는 Apple이 제공하는 한국어 표기 "Apple로 로그인"을 쓴다.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    required this.onPressed,
    this.loading = false,
    this.label = 'Apple로 로그인',
    super.key,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  static const _height = 48.0;
  static const _logoSize = 20.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.appleWhiteFill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          overlayColor: WidgetStatePropertyAll(
            AppColors.appleWhiteText.withValues(alpha: 0.08),
          ),
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.apple,
                    size: _logoSize + 2,
                    color: AppColors.appleWhiteText,
                  ),
                  const SizedBox(width: 8),
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.appleWhiteText,
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
                          fontWeight: FontWeight.w600,
                          color: AppColors.appleWhiteText,
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
