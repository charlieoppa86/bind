import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_spacing.dart';

/// BIND 로고(그라데이션 마크 + BIND 글자). 앱이 다크 모드라 글자만 흰색인 버전을 쓴다.
///
/// 이미지: `assets/images/bind_logo_white.png`(1x~4x, 1x 높이 32). 원본은
/// `assets/images/app_icon.png`이고, 배경을 지워 잘라낸 원래 색 버전(`bind_logo.png`)도 함께 있다.
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

/// BIND 그라데이션 마크(로고의 N 모양만). 탭 화면 AppBar 왼쪽에 쓴다.
///
/// 이미지: `assets/images/bind_mark.png`(1x~4x, 1x 높이 20). 원본은 홈 화면 아이콘
/// 전경 `assets/icon/app_icon_foreground.png`에서 여백 없이 마크만 잘라 낸 것.
class BindMark extends StatelessWidget {
  const BindMark({this.size = 20, super.key});

  /// 마크 높이(dp). 너비는 비율대로 정해진다.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/bind_mark.png',
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}

/// AppBar 제목 왼쪽에 BIND 마크를 붙인다(체크인·채팅·요청·마이페이지 탭 공통).
class BrandedTitle extends StatelessWidget {
  const BrandedTitle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BindMark(),
        const SizedBox(width: AppSpacing.sm + 2),
        Flexible(child: child),
      ],
    );
  }
}
