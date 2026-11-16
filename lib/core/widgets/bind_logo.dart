import 'package:material_ui/material_ui.dart';

/// BIND 워드마크. 앱이 다크 모드라 흰색 버전을 쓴다.
///
/// 이미지: `assets/images/bind_logo_white.png`(1x~4x). 원본은 `assets/images/app_icon.png`
/// 위쪽 로고를 잘라 만든 것이고, 검정 버전(`bind_logo.png`)도 함께 있다.
class BindLogo extends StatelessWidget {
  const BindLogo({this.size = 32, super.key});

  /// 로고 높이(dp). 너비는 비율대로 정해진다.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/bind_logo_white.png',
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'BIND',
    );
  }
}
