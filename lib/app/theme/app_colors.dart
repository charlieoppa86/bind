import 'package:material_ui/material_ui.dart';

/// docs/DESIGN.md `colors` 토큰.
/// `#0066ff`(primary)는 행동·선택 의미에만 쓴다.
abstract final class AppColors {
  static const primary = Color(0xFF0066FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFFFFFF);
  static const heading = Color(0xFF171719);
  static const body = Color(0xFF333333);
  static const secondary = Color(0xFF858688);
  static const subtleSurface = Color(0xFFF8F8F8);
  static const hairline = Color(0xFFE8E9EA);

  // ── BIND 확장 토큰 (토스류 앱 패턴 참고, 2026-11-15) ──
  /// 그룹 화면 배경. 흰 카드를 올려 섹션을 나눈다.
  static const groupedBackground = Color(0xFFF2F4F6);

  /// 입력칸·보조 버튼·칩의 채움색(테두리 대신 면으로 구분)
  static const fill = Color(0xFFF2F4F6);

  /// 선택 상태의 옅은 배경(선택 의미일 때만)
  static const primarySoft = Color(0xFFE8F1FF);

  /// 비활성·플레이스홀더 텍스트
  static const tertiary = Color(0xFFB0B8C1);

  /// 닉네임 아바타 (배경, 글자) 쌍. 사진 대신 목록에서 사람을 구분하는 용도.
  static const avatarTints = <(Color, Color)>[
    (Color(0xFFE8F1FF), Color(0xFF1B64DA)),
    (Color(0xFFE5F7EE), Color(0xFF0E8A4F)),
    (Color(0xFFFFF1E0), Color(0xFFC2620A)),
    (Color(0xFFF3EBFF), Color(0xFF7B3FE4)),
    (Color(0xFFFFE9EE), Color(0xFFD22A55)),
    (Color(0xFFE6F6F8), Color(0xFF0B8494)),
  ];

  /// 컨트롤 경계선: rgba(112,115,124,0.16) 1px inset.
  static const controlBorder = Color(0x2970737C);

  /// 눌림/호버 state layer 색(#171719 + 낮은 opacity).
  static const stateLayer = heading;

  /// DESIGN.md에 시맨틱 에러 색은 정의돼 있지 않다.
  /// 폼 검증·신고 등 최소한의 오류 표시용으로만 임시 사용한다.
  static const error = Color(0xFFE5484D);
}
