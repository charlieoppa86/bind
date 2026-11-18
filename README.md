# BIND

**같은 공간에서 같은 관심사로. 우리들의 스몰톡, 바인드.**

BIND는 같은 공간(카페, 코워킹, 도서관, 행사장)에 있는 사람이 "지금 얘기하고 싶은 주제" 한 줄을 띄우고, 주제가 맞는 사람끼리 대화를 요청해 1:1 채팅을 여는 Flutter 앱(Android/iOS)입니다. 약속 없이 지금 같은 공간에서 10분 안에 대화를 시작하는 데 집중합니다.

> 앱은 **Firebase(프로젝트 `bind-app-2026`)에 연결**되어 실제 데이터로 동작합니다. 테스트와 Firebase 설정이 없는 환경에서는 같은 화면이 **데모 모드**(앱 안 더미 데이터)로 돌아갑니다. 위치(GPS)는 쓰지 않습니다.

## 핵심 흐름

1. **가입**: Google로 로그인(iOS는 Apple 로그인도) → 닉네임·하는 일 → 만 19세 이상 확인과 이용 규칙 3줄 동의 → 사용법 가이드
2. **체크인**: 한 화면에서 **장소**(카카오 장소 검색) → **주제** 한 줄(30자) → **키워드**(24개, 기타는 직접 입력)를 정하면 끝
3. **같은 장소**: 같은 카카오 장소를 고른 사람끼리 서로의 주제 카드를 봄. 체류 시간 제한 없이 체크아웃할 때까지 보임. 인원은 나를 뺀 수로 표시
4. **요청·수락**: 상대 카드에 "어떤 대화를 하고 싶어요?" 한 마디(40자)를 붙여 요청 → 카드 주인이 수락해야 대화방이 열림(30분 무응답 시 만료, 무료는 하루 5번)
5. **대화**: 1:1 텍스트 채팅, 7일 뒤 자동 삭제. 나갈 때 "좋았어요 / 그저 그래요" 평가
6. **안전**: 카드·요청·대화방에서 신고·차단, 서로 다른 2명에게 신고되면 이용 정지

하단 탭은 **체크인 · 채팅 · 요청 · 마이페이지**입니다. BIND+(주제 3개·요청 무제한)는 출시 후 결제를 붙이며, 지금은 "준비 중" 안내만 뜹니다.

## 실행하기

**요구 사항**: Flutter 3.50 / Dart 3.14, Google Play가 들어 있는 Android 에뮬레이터(Google 로그인에 최신 Play 서비스 필요) 또는 iOS 시뮬레이터

```bash
flutter pub get
flutter run
```

- 에뮬레이터에 Google 계정이 로그인되어 있어야 Google 로그인이 됩니다(설정 → 계정 → Google 추가).
- 처음부터 다시 보려면 앱 데이터를 지웁니다: `adb shell pm clear app.bind.mobile` (서버의 계정·데이터는 그대로)

### 데모 모드(테스트·Firebase 미설정 환경)

- 데모 장소: 성수 워크라운지, 연무장길 팝업 스토어, 판교 프로덕트 컨퍼런스, 연남 코워킹 하우스, 신촌 중앙도서관 등(장소 검색이 이 목록에서 찾습니다)
- 상대 반응은 시나리오대로 자동으로 일어납니다: 체크인 몇 초 뒤 요청이 오고, 내가 요청하면 5초 뒤 수락(일부는 거절), 메시지를 보내면 2초 뒤 답장이 옵니다.

## 개발 명령

```bash
flutter analyze   # 정적 분석
flutter test      # 위젯·단위 테스트
```

변경 후에는 두 명령을 모두 통과시킵니다.

### Firebase·서버

```bash
firebase deploy --only firestore          # 보안 규칙·인덱스(firestore.rules, firestore.indexes.json)
firebase deploy --only functions          # Cloud Functions(functions/src/index.ts)
firebase functions:secrets:set KAKAO_REST_API_KEY --project bind-app-2026   # 카카오 REST 키(앱·저장소에 넣지 않음)
```

| Cloud Functions | 하는 일 |
| --- | --- |
| `searchPlaces` | 카카오 장소 검색 대신 호출 |
| `sendRequest` / `respondRequest` / `expireRequests` | 대화 요청(같은 장소·하루 횟수·중복·차단 확인), 수락 시 채팅방 생성, 30분 만료 |
| `onCheckinWritten` | 장소의 지금 인원 집계, 빈 장소 첫 입장 푸시 |
| `onMessageCreated` | 마지막 메시지·안 읽은 수, 새 메시지 푸시 |
| `onReportCreated` / `onReviewCreated` | 신고 누적 정지, 좋았어요 수·신뢰 표시 |
| `onRequestWritten` | 요청 도착·수락·거절·만료 푸시 |
| `sendTopicPush` / `sendTestPush` | 토픽 발송(관리자 클레임 `admin`) / 내 기기로 테스트 발송 |
| `deleteAccount` | 탈퇴(Apple 계정은 앱이 먼저 Apple 토큰 해지, 닉네임 해제·떠난 사용자 표시·카드 내림·푸시 토큰 삭제·계정 삭제) |

## 구조

```
lib/
  app/              앱 위젯, 라우터(go_router), 테마
  core/
    constants/      AppLimits(모든 수치 규칙), enums(키워드 24개·하는 일 30개), Brand(슬로건), 예시 주제·이용 규칙
    notice/         앱 안 알림 배너
    utils/          한글 초성 검색, 시간 표시
    widgets/        공용 위젯(BindLogo·BindMark, Pressable, SelectChip, ConfirmDialog, GoogleSignInButton …)
  data/
    models/         Firestore 문서 모델
    account/        로그인·프로필(Firebase / 데모)
    place/          카카오 장소 검색(Functions / 데모)
    live/           Firestore 저장소와 LiveSync(실시간 데이터 → 앱 안 저장소)
    demo/           앱 안 저장소(demo_store.dart)·파생 provider·더미 데이터
  features/         화면: auth, onboarding, guide, checkin, spot, requests, chat, my, safety, session
functions/          Cloud Functions(TypeScript)
docs/               기획 문서
test/               흐름·단위 테스트
```

- **스택**: Flutter, flutter_riverpod 3(`Notifier`, 바뀐 데이터 묶음만 다시 그리는 파생 provider), go_router(하단 탭 4개는 `StatefulShellRoute`), Firebase(Auth, Firestore 서울, Cloud Functions)
- **라우팅 가드**: `features/session/session.dart`의 세션 상태(로그인·온보딩·정지·체크인)로 화면을 나눕니다. 로그인·프로필은 `AccountController`가 맡습니다.
- **디자인**: 다크 모드가 기본입니다. 색·글꼴·간격은 `AppColors` / `AppTypography` / `AppSpacing` / `AppRadius` 토큰만 씁니다. 숫자 규칙(30자, 40자, 30분 등)은 `AppLimits`, 문구는 `Brand`에서 가져옵니다.

## 기획 문서

| 문서 | 내용 |
| --- | --- |
| [`docs/BIND_blueprint.md`](docs/BIND_blueprint.md) | 전략, 타겟, 비즈니스 모델, MVP 범위, 위험한 가정 |
| [`docs/BIND_userstory.md`](docs/BIND_userstory.md) | 사용자 스토리 US-001~023과 인수 조건 |
| [`docs/BIND_IA.md`](docs/BIND_IA.md) | 화면 구조와 라우트 매핑 |
| [`docs/DESIGN.md`](docs/DESIGN.md) | 디자인 토큰, 다크 모드, 로고·아이콘, 키워드 칩 |

## 남은 일

- **iOS 푸시**: Firebase 콘솔에 APNs 인증 키(.p8) 등록, Xcode에서 서명 팀 지정(Push Notifications 권한은 `Runner.entitlements`에 있음)
- **App Check·API 키 제한**: 정식 앱에서 온 요청만 서버가 받게(출시 전)
- **결제**: BIND+ 구독(출시 후)
- **주제 개수 제한 서버 확인**: 무료 1개·BIND+ 3개를 서버에서도 확인
- **출시 전 법률 검토**: 체크인한 장소를 저장하는 구조가 위치정보법 적용 대상인지, 양방향 채팅이 부가통신사업 신고 대상인지 확인합니다.
