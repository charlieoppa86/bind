import 'package:material_ui/material_ui.dart';

/// 앱 색 토큰 — **다크 모드 기본** (2026-11-16).
///
/// 이름(역할)은 docs/DESIGN.md를 따르고 값만 어두운 배경용으로 바꿨다.
/// 라이트 값은 DESIGN.md의 `colors`에 남아 있다.
/// primary는 행동·선택 의미에만 쓴다. 어두운 배경에서 글자로 쓸 때 읽히도록
/// DESIGN.md의 #0066ff보다 밝은 값을 쓴다.
abstract final class AppColors {
  static const primary = Color(0xFF2F80FF);
  static const onPrimary = Color(0xFFFFFFFF);

  /// 화면·카드 바탕
  static const canvas = Color(0xFF17171C);

  /// 제목·주요 글자
  static const heading = Color(0xFFF4F5F7);

  /// 본문 글자
  static const body = Color(0xFFD4D6DB);

  /// 보조 글자(메타데이터)
  static const secondary = Color(0xFF9EA2AB);
  static const subtleSurface = Color(0xFF1F1F25);
  static const hairline = Color(0xFF2E2E36);

  // ── BIND 확장 토큰 (토스류 앱 패턴 참고) ──
  /// 그룹 화면 배경. 카드([canvas])보다 한 단계 어둡다.
  static const groupedBackground = Color(0xFF0E0E12);

  /// 입력칸·보조 버튼·칩의 채움색(테두리 대신 면으로 구분)
  static const fill = Color(0xFF26262D);

  /// 떠 있는 면: 알림 배너, 내 주제 카드, 스낵바처럼 바탕보다 밝게 띄울 것
  static const elevated = Color(0xFF2C2C34);

  /// 선택 상태의 옅은 배경(선택 의미일 때만)
  static const primarySoft = Color(0xFF16294D);

  /// 비활성·플레이스홀더 텍스트
  static const tertiary = Color(0xFF6A6E78);

  /// 그림자(어두운 배경에서도 검정)
  static const shadow = Color(0xFF000000);

  /// 닉네임 아바타 (배경, 글자) 쌍. 사진 대신 목록에서 사람을 구분하는 용도.
  static const avatarTints = <(Color, Color)>[
    (Color(0xFF1A2B4D), Color(0xFF7FB0FF)),
    (Color(0xFF143326), Color(0xFF5FD39A)),
    (Color(0xFF3A2A14), Color(0xFFFFB566)),
    (Color(0xFF2D2145), Color(0xFFB896FF)),
    (Color(0xFF3D1A25), Color(0xFFFF7FA0)),
    (Color(0xFF123236), Color(0xFF5FD0DC)),
  ];

  // ── 외부 브랜드 가이드 고정값(바꾸지 않는다) ──
  /// Google 로그인 버튼 Dark 테마
  /// (https://developers.google.com/identity/branding-guidelines)
  static const googleDarkFill = Color(0xFF131314);
  static const googleDarkStroke = Color(0xFF8E918F);
  static const googleDarkText = Color(0xFFE3E3E3);

  /// 컨트롤 경계선
  static const controlBorder = Color(0x29FFFFFF);

  /// 눌림/호버 state layer 색. 어두운 바탕에서는 밝게 덮는다.
  static const stateLayer = heading;

  /// DESIGN.md에 시맨틱 에러 색은 정의돼 있지 않다.
  /// 폼 검증·신고 등 최소한의 오류 표시용으로만 임시 사용한다.
  static const error = Color(0xFFFF5D62);
}
