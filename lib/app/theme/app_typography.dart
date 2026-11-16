import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// docs/DESIGN.md `typography` 토큰. 폰트는 Pretendard.
abstract final class AppTypography {
  static const fontFamily = 'Pretendard';

  // ── BIND 확장 토큰 ──
  /// 화면 대표 제목 26/700 (한 화면에 하나)
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.38,
    letterSpacing: -0.6,
    color: AppColors.heading,
  );

  /// 카드·시트 제목 20/700
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: -0.4,
    color: AppColors.heading,
  );

  /// 읽기용 큰 본문 16/400
  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.2,
    color: AppColors.body,
  );

  /// 섹션 제목 22/600, line-height 1.36.
  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.36,
    letterSpacing: -0.4268,
    color: AppColors.heading,
  );

  /// 카드 제목(주제 한 줄 등) 16/600.
  static const subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.0912,
    color: AppColors.heading,
  );

  /// 보조 제목·탭 라벨 15/600.
  static const supportingTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
    letterSpacing: 0.144,
    color: AppColors.heading,
  );

  /// 본문 14/400.
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    color: AppColors.body,
  );

  /// 메타데이터(직무 태그·시간) 12/500.
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
    letterSpacing: 0.3024,
    color: AppColors.secondary,
  );

  /// 큰 CTA 라벨 16/600.
  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  static const textTheme = TextTheme(
    headlineSmall: heading,
    titleMedium: subtitle,
    titleSmall: supportingTitle,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
  );
}
