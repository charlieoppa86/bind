# BIND 앱

같은 공간(스팟)에 체크인한 사람끼리 "주제 한 줄"로 1:1 대화를 시작하는 Flutter 앱 (Android/iOS).

## 기획 문서 (구현 전 반드시 확인)
- `docs/BIND_blueprint.md` — 전략, MVP 범위, 빼는 기능
- `docs/BIND_userstory.md` — 사용자 스토리 US-001~023과 Acceptance Criteria
- `docs/BIND_IA.md` — 화면 구조와 go_router 라우트 매핑
- `docs/DESIGN.md` — 디자인 토큰(색·타이포·라운드)

## 스택
- Flutter 3.50 / Dart 3.14. Material은 `package:material_ui/material_ui.dart`로 import한다.
- 상태관리: flutter_riverpod 3 (`Notifier` / `NotifierProvider`)
- 라우팅: go_router, 하단 탭 4개는 `StatefulShellRoute.indexedStack`
- 백엔드: Firebase(Auth, Firestore, Cloud Functions, FCM, Analytics). 서버 직접 구축 금지.

## 폴더 구조
- `lib/app/` — 앱 위젯, 라우터(`router/`), 테마(`theme/`), Firebase 초기화
- `lib/core/constants/` — `AppLimits`(모든 수치 규칙), `enums.dart`(직무·카테고리·신고 사유 등)
- `lib/core/widgets/` — 공용 위젯
- `lib/data/models/` — Firestore 문서 모델 (컬렉션 경로는 각 클래스 주석 참고)
- `lib/features/<기능>/presentation/` — 화면. 기능: auth, onboarding, guide, checkin, spot, requests, chat, my, safety, session

## 규칙
- 경로 문자열은 `Routes`(lib/app/router/routes.dart)만 사용한다.
- 30자·40자·30분·7일 같은 숫자는 `AppLimits`에서 가져온다. 화면에 숫자를 직접 쓰지 않는다.
- 색·글꼴·간격은 `AppColors` / `AppTypography` / `AppSpacing` / `AppRadius`만 사용한다. `primary`는 행동·선택에만.
- 앱은 **다크 모드 기본**이다(`AppColors` 값이 다크 팔레트). `heading`을 배경으로 쓰지 말고 띄울 면은 `elevated`를 쓴다. 자세한 값은 docs/DESIGN.md "다크 모드 기본".
- 연애·만남 카테고리는 영구 제외(US-W08).
- **위치(GPS)·PIN·체류 시간 제한은 없다**(2026-11-16 결정). 체크인은 한 화면에서 장소 이름을 자유롭게 입력하고 주제 한 줄을 올리면 끝난다.
- 같은 장소 판정은 장소 이름(띄어쓰기·대소문자 무시, `Spot.key`)이 같은지로 한다. 입력하는 동안 이미 있는 장소를 추천해 같은 이름으로 모이게 한다. 체크아웃할 때까지 카드가 보인다.
- 신뢰가 필요한 값(정지 여부, 신고 누적, 좋았어요 수, 신청 만료, 채팅방 생성)은 클라이언트가 아니라 Cloud Functions가 쓴다.
- 지금은 **데모 모드**다. 모든 화면이 `lib/data/demo/demo_store.dart`(`demoStoreProvider`, 메모리 저장소)를 읽고 쓴다. 더미 데이터·시나리오(상대 수락·답장·신청 도착 지연)는 `demo_seed.dart`에 있다. Firebase 연결 시 화면 코드의 `TODO(firebase)` 위치를 Firestore/Functions 호출로 바꾼다.
- 세션(`lib/features/session/session.dart`)은 라우터 가드의 기준이다. 데모 저장소가 로그인·온보딩·체크인 시 세션을 갱신한다. Firebase 연결 시 이 Notifier만 교체하면 라우터 가드는 그대로 동작한다.
- 앱 안 알림(신청 도착·수락·만료 등)은 `inAppNoticeProvider`로 보내면 화면 위 배너로 뜬다.

## 명령
- `flutter analyze` / `flutter test` — 변경 후 항상 둘 다 통과시킨다
- `flutter run`
