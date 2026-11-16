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
- **위치(GPS)·PIN·체류 시간 제한은 없다**(2026-11-16 결정). 체크인은 한 화면에서 장소를 검색해 고르고 주제 한 줄을 올리면 끝난다.
- 장소는 **카카오 로컬 키워드 장소 검색**으로 고른다(2026-11-16 결정, 우편번호 서비스는 가게 이름 검색이 안 돼서 제외). 같은 장소 판정은 카카오 장소 ID(`Spot.placeId`, Firestore `spots/{placeId}`)로 한다. 체크아웃할 때까지 카드가 보인다.
- 카카오 REST 키는 앱에 넣지 않는다. 검색은 Cloud Functions `searchPlaces`(functions/src/index.ts, Secret `KAKAO_REST_API_KEY`)가 대신 호출한다. 앱은 `placeSearchProvider`(lib/data/place/place_search.dart)만 쓰고, 데모 모드에서는 `DemoPlaceSearch`, Firebase 연결 시 main.dart가 `FunctionsPlaceSearch`로 바꿔 끼운다.
- 신뢰가 필요한 값(정지 여부, 신고 누적, 좋았어요 수, 신청 만료, 채팅방 생성)은 클라이언트가 아니라 Cloud Functions가 쓴다.
- Firebase 프로젝트는 `bind-app-2026`(Firestore 서울 `asia-northeast3`, Functions 같은 리전), 앱 식별자는 Android·iOS 모두 `app.bind.mobile`.
- **1단계(연결됨)**: 로그인·프로필은 `AccountController`(lib/features/session/account_controller.dart) → `AccountRepository`(lib/data/account/). Firebase가 초기화되면 main.dart가 `FirebaseAccountRepository`(Google 로그인 + `users/{uid}` + 닉네임 예약 `nicknames/{key}`)로 바꿔 끼운다. 보안 규칙은 `firestore.rules`(배포: `firebase deploy --only firestore:rules`).
- **데이터 흐름(2단계 완료)**: 화면은 `lib/data/demo/demo_store.dart`(`demoStoreProvider`, 앱 안 저장소)와 파생 provider(`demo_providers.dart`)만 본다.
  - 데모 모드(`liveModeProvider` false, 테스트 포함): 저장소가 `demo_seed.dart` 더미 데이터·시나리오로 시작한다.
  - 실제 모드(Firebase 연결 시 main.dart가 true로): 저장소가 비어서 시작하고 `LiveSync`(lib/data/live/live_sync.dart)가 Firestore 실시간 데이터(내 카드·장소 피드·요청·채팅방·차단·내 프로필)를 넣는다. 저장소 메서드는 화면에 먼저 반영하고 Firestore에 쓴다. 서버의 내 uid는 앱 안에서 `DemoDb.myUid`로 바꿔 넣는다.
  - 신뢰가 필요한 일은 Functions: 요청 보내기·수락(`sendRequest`/`respondRequest`), 만료(`expireRequests`), 장소 인원(`onCheckinWritten`), 마지막 메시지·안 읽은 수(`onMessageCreated`), 정지(`onReportCreated`), 좋았어요 수(`onReviewCreated`), 탈퇴(`deleteAccount`).
- 세션(`lib/features/session/session.dart`)은 라우터 가드의 기준이다. 데모 저장소가 로그인·온보딩·체크인 시 세션을 갱신한다. Firebase 연결 시 이 Notifier만 교체하면 라우터 가드는 그대로 동작한다.
- 앱 안 알림(신청 도착·수락·만료 등)은 `inAppNoticeProvider`로 보내면 화면 위 배너로 뜬다.

## 명령
- `flutter analyze` / `flutter test` — 변경 후 항상 둘 다 통과시킨다
- `flutter run`
