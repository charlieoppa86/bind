# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# BIND 앱

같은 공간(스팟)에 체크인한 사람끼리 "주제 한 줄"로 1:1 대화를 시작하는 Flutter 앱 (Android/iOS).

## 기획 문서 (구현 전 반드시 확인)
- `docs/BIND_blueprint.md` — 전략, MVP 범위, 빼는 기능
- `docs/BIND_userstory.md` — 사용자 스토리 US-001~023과 Acceptance Criteria
- `docs/BIND_IA.md` — 화면 구조와 go_router 라우트 매핑
- `docs/DESIGN.md` — 디자인 토큰(색·타이포·라운드)

## 명령
```bash
flutter analyze                                   # 변경 후 항상 통과
flutter test                                      # 변경 후 항상 통과
flutter test test/app_flow_test.dart              # 파일 하나
flutter test --plain-name '로그인 → 온보딩'        # 이름으로 테스트 하나
flutter run

npm --prefix functions run build                  # Cloud Functions(TypeScript) 컴파일 확인
firebase deploy --only firestore                  # firestore.rules + firestore.indexes.json
firebase deploy --only functions                  # predeploy가 build를 먼저 돌린다
firebase functions:secrets:set KAKAO_REST_API_KEY --project bind-app-2026
dart run flutter_launcher_icons                   # 앱 아이콘 다시 생성(pubspec 설정)
```
- 테스트는 Firebase 없이 **데모 모드**로 돈다(`ProviderScope(child: BindApp())`만으로 전체 흐름이 동작). `test/app_flow_test.dart`가 로그인→채팅 전체 흐름 테스트다.
- 린트는 `flutter_lints` + `prefer_const_*` 규칙. 정적 위젯은 `const`로 만든다.

## 스택
- Flutter 3.50 / Dart 3.14. Material은 `package:material_ui/material_ui.dart`로 import한다.
- 상태관리: flutter_riverpod 3 (`Notifier` / `NotifierProvider`)
- 라우팅: go_router, 하단 탭 4개(체크인·채팅·요청·마이페이지)는 `StatefulShellRoute.indexedStack`
- 백엔드: Firebase(Auth, Firestore, Cloud Functions, FCM, Analytics, App Check). 서버 직접 구축 금지.
- Firebase iOS SDK는 SPM으로 받는다(`pubspec.yaml`의 `enable-swift-package-manager`).

## 폴더 구조
- `lib/app/` — 앱 위젯, 라우터(`router/`), 테마(`theme/`), Firebase 초기화(`firebase_bootstrap.dart`)
- `lib/core/constants/` — `AppLimits`(모든 수치 규칙), `enums.dart`(하는 일·키워드·신고 사유 등), `brand.dart`(슬로건·문구)
- `lib/core/widgets/` — 공용 위젯
- `lib/data/models/` — Firestore 문서 모델 (컬렉션 경로는 각 클래스 주석 참고)
- `lib/data/{account,place,live,demo}/` — 데이터 계층(아래 "데모/실제 모드" 참고)
- `lib/features/<기능>/presentation/` — 화면. 기능: auth, onboarding, guide, checkin, spot, requests, chat, my, safety, session
- `functions/src/index.ts` — Cloud Functions 전부(Node 22)

## 데모/실제 모드 (아키텍처 핵심)
같은 화면이 두 모드로 돈다. 전환은 `lib/main.dart`의 `ProviderScope` override 한 곳에서만 일어난다. Firebase 초기화에 성공하면 아래 provider를 실제 구현으로 바꿔 끼우고, 실패하거나 테스트면 기본값(데모)을 쓴다.

| provider | 데모(기본) | 실제(main.dart override) |
| --- | --- | --- |
| `liveModeProvider` | false | true |
| `accountRepositoryProvider` | `DemoAccountRepository` | `FirebaseAccountRepository` |
| `placeSearchProvider` | `DemoPlaceSearch` | `FunctionsPlaceSearch` |
| `pushPlatformProvider` | `NoopPushPlatform` | `FirebasePushPlatform` |

새 외부 의존은 이 패턴(인터페이스 + 데모 구현 + main.dart override)을 따른다.

- **화면은 `lib/data/demo/demo_store.dart`(`demoStoreProvider`, 앱 안 저장소)와 파생 provider(`demo_providers.dart`)만 본다.** Firestore를 화면에서 직접 읽지 않는다.
  - 데모 모드: 저장소가 `demo_seed.dart` 더미 데이터·시나리오로 시작한다(체크인 후 요청 도착, 5초 뒤 수락, 2초 뒤 답장 등).
  - 실제 모드: 저장소가 비어서 시작하고 `LiveSync`(lib/data/live/live_sync.dart)가 Firestore 실시간 데이터(내 카드·장소 피드·요청·채팅방·차단·내 프로필)를 넣는다. 저장소 메서드는 화면에 먼저 반영하고 `lib/data/live/*_repository.dart`로 Firestore에 쓴다. 서버의 내 uid는 앱 안에서 `DemoDb.myUid`로 바꿔 넣는다.
- 파생 provider는 바뀐 데이터 묶음만 다시 그리게 쪼개 둔다(`test/fine_grained_rebuild_test.dart`가 검사).
- **로그인·프로필**은 `AccountController`(lib/features/session/account_controller.dart) → `AccountRepository`(lib/data/account/). 실제 모드는 Google 로그인(iOS는 Apple 로그인도, `AppleSignInButton`은 iOS에서만 보임) + `users/{uid}` + 닉네임 예약 `nicknames/{key}`. Apple로 가입한 계정은 탈퇴 전 `revokeForDeletion`이 Apple 토큰을 해지한다(App Store 규정).
- **세션**(`lib/features/session/session.dart`)은 라우터 가드의 기준(로그인·온보딩·정지·체크인)이다. 데모 저장소가 로그인·온보딩·체크인 시 세션을 갱신한다. 이 Notifier만 교체하면 라우터 가드는 그대로 동작한다.
- **신뢰가 필요한 값은 Cloud Functions가 쓴다**(클라이언트 금지): 요청 보내기·수락(`sendRequest`/`respondRequest`, 수락 시 채팅방 생성), 만료(`expireRequests`), 장소 인원(`onCheckinWritten`), 마지막 메시지·안 읽은 수·성사 시각(`onMessageCreated`), 일별 지표(`aggregateDailyMetrics` → `metrics/{YYYY-MM-DD}`, 앱은 읽기 불가), 정지(`onReportCreated`), 좋았어요 수(`onReviewCreated`), 요청 푸시(`onRequestWritten`), 탈퇴(`deleteAccount`). 보안 규칙은 `firestore.rules`.
- **앱 안 알림**(요청 도착·수락·만료 등)은 `inAppNoticeProvider`로 보내면 화면 위 배너로 뜬다.
- **푸시(FCM)**는 `PushController`(lib/core/push/, `pushProvider`)가 권한·토큰(`users/{uid}/fcmTokens`)·토픽·받은 알림을 관리한다. 서버는 data에 `type`·`route`를 넣어 보내고, 앱은 `PushRoute.parse`로 허용된 앱 안 경로만 연다. 알림 채널 id는 `bind_default`(앱·서버 같게). 백그라운드 핸들러는 `runApp` 전에 등록한다.

## 규칙
- 경로 문자열은 `Routes`(lib/app/router/routes.dart)만 사용한다.
- 30자·40자·30분·7일 같은 숫자는 `AppLimits`에서 가져온다. 화면에 숫자를 직접 쓰지 않는다. 문구는 `Brand`.
- 색·글꼴·간격은 `AppColors` / `AppTypography` / `AppSpacing` / `AppRadius`만 사용한다. `primary`는 행동·선택에만.
- **아이폰·아이패드 모두 지원, 세로 고정**(iPad는 `UIRequiresFullScreen`, 멀티태스킹 미지원). 레이아웃 기준 기기는 iPad Air 11"(M4, 820pt)·iPad Pro 13"(M4, 1032pt). 넓은 화면에서는 `ContentWidthFrame`(lib/app/)이 앱 전체를 `AppSpacing.maxContentWidth`(640) 가운데 열로 모으므로 화면마다 따로 너비를 제한하지 않는다. `test/app_flow_test.dart`가 폰·두 아이패드 크기로 전체 흐름을 돈다.
- 앱은 **다크 모드 기본**이다(`AppColors` 값이 다크 팔레트). `heading`을 배경으로 쓰지 말고 띄울 면은 `elevated`를 쓴다. 자세한 값은 docs/DESIGN.md "다크 모드 기본".
- 연애·만남 키워드는 영구 제외(US-W08). 키워드는 24개(`TopicCategory`, 이름은 Firestore에 저장되므로 바꾸지 않는다)이고 기타는 직접 입력(`Checkin.categoryCustom`).
- **위치(GPS)·PIN·체류 시간 제한은 없다**(2026-11-16 결정). 체크인은 한 화면에서 장소를 검색해 고르고 주제 한 줄을 올리면 끝난다. 체크아웃할 때까지 카드가 보인다.
- 장소는 **카카오 로컬 키워드 장소 검색**으로 고른다(2026-11-16 결정, 우편번호 서비스는 가게 이름 검색이 안 돼서 제외). 같은 장소 판정은 카카오 장소 ID(`Spot.placeId`, Firestore `spots/{placeId}`)로 한다.
- 카카오 REST 키는 앱에 넣지 않는다. 검색은 Cloud Functions `searchPlaces`(Secret `KAKAO_REST_API_KEY`)가 대신 호출한다. 앱은 `placeSearchProvider`(lib/data/place/place_search.dart)만 쓴다.
- 약관·개인정보처리방침은 별도 저장소 `charlieoppa86/bind-policy`(GitHub Pages)에 있다. 앱 밖 주소와 문의 이메일은 `AppLinks`(lib/core/links/app_links.dart)만 쓰고, 열 때는 `openLink`를 쓴다(테스트는 `linkOpenerProvider`를 바꿔 끼움). 수집 항목·보관 기간·탈퇴 처리(`deleteAccount`, TTL)를 바꾸면 방침도 같이 고친다.
- `assets/images/`의 Google G 로고는 공식 에셋을 자른 것이라 수정·재채색 금지.
- Firebase 프로젝트는 `bind-app-2026`(Firestore 서울 `asia-northeast3`, Functions 같은 리전), 앱 식별자는 Android·iOS 모두 `app.bind.mobile`.
