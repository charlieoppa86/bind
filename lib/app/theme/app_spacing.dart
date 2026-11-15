/// docs/DESIGN.md `spacing` / `rounded` 토큰.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 40;

  /// 화면 좌우 여백
  static const double page = 24;

  /// 큰 CTA 높이
  static const double ctaHeight = 56;
}

abstract final class AppRadius {
  /// 버튼·입력 등 컨트롤.
  static const double control = 8;

  /// 카드·큰 CTA.
  static const double card = 12;

  /// 메뉴·바텀시트 등 오버레이.
  static const double menu = 16;

  static const double full = 9999;

  // ── BIND 확장 토큰 ──
  /// 큰 CTA 버튼
  static const double button = 16;

  /// 큰 카드·섹션
  static const double section = 20;

  /// 바텀시트 상단
  static const double sheet = 24;
}
