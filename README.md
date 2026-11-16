# BIND

**지금 여기, 같은 주제의 사람과 바로 대화.**

BIND는 같은 공간(카페, 코워킹, 도서관, 행사장)에 있는 사람이 "지금 얘기하고 싶은 주제" 한 줄을 띄우고, 주제가 맞는 사람끼리 대화를 신청해 1:1 채팅을 여는 Flutter 앱(Android/iOS)입니다. 약속 없이 "지금, 여기"에서 10분 안에 대화를 시작하는 데 집중합니다.

> 현재는 **데모 모드**입니다. Firebase 없이 앱 안의 더미 데이터로 전체 흐름을 체험할 수 있습니다. 위치(GPS)는 쓰지 않습니다.

## 핵심 흐름

1. **가입**: 구글(iOS는 구글·애플)로 로그인 → 닉네임·하는 일 → 만 19세 이상 확인과 이용 규칙 3줄 동의 → 사용법 가이드
2. **체크인**: 한 화면에서 지금 있는 **장소를 검색해 고르고**(카카오 장소 검색) 주제 한 줄(30자) + 카테고리를 올리면 끝. 같은 카카오 장소를 고른 사람끼리 모임
3. **같은 장소**: 같은 장소를 입력한 사람끼리 서로의 주제 카드를 봄. 체류 시간 제한 없이 체크아웃할 때까지 보임
4. **신청·수락**: 같은 방 사람의 주제 카드에 한 마디(40자)를 붙여 신청 → 상대가 수락해야 대화방이 열림(30분 무응답 시 만료)
5. **대화**: 1:1 텍스트 채팅, 7일 뒤 자동 삭제. 나갈 때 "좋았어요 / 그저 그래요" 평가
6. **안전**: 카드·신청·대화방에서 신고·차단, 서로 다른 2명에게 신고되면 이용 정지

같은 장소인지는 장소 이름으로 판단합니다(띄어쓰기·대소문자 무시). 위치(GPS)·입장 PIN·체류 시간 제한은 없습니다.

## 실행하기

**요구 사항**: Flutter 3.50 / Dart 3.14, Android 에뮬레이터 또는 iOS 시뮬레이터

```bash
flutter pub get
flutter run
```

### 데모 모드에서 테스트하는 법

- **같은 장소로 들어가기**: 장소 칸에 `워크라`처럼 일부만 적으면 이미 있는 장소가 추천됩니다. 데모 장소는 성수 워크라운지, 연무장길 팝업 스토어, 판교 프로덕트 컨퍼런스, 연남 코워킹 하우스, 신촌 중앙도서관입니다.
- **새 장소 열기**: 목록에 없는 이름을 적으면 새 장소로 열리고, 아직 아무도 없는 피드가 보입니다("누가 오면 알려줘"를 켜면 몇 초 뒤 누군가 들어옵니다).
- **상대 반응은 시나리오대로 자동으로 일어납니다**: 체크인 몇 초 뒤 신청이 오고, 내가 신청하면 5초 뒤 수락(일부는 거절), 메시지를 보내면 2초 뒤 답장이 옵니다.
- **처음 상태로 되돌리기**: 앱을 다시 실행하거나 마이 > 계정 > 탈퇴하기.
- **이용 정지 화면**: 디버그 빌드의 마이 > 계정 > "이용 정지 화면 미리보기".

## 개발 명령

```bash
flutter analyze   # 정적 분석
flutter test      # 위젯·단위 테스트
```

변경 후에는 두 명령을 모두 통과시킵니다.

## 구조

```
lib/
  app/              앱 위젯, 라우터(go_router), 테마
  core/
    constants/      AppLimits(모든 수치 규칙), enums, 예시 주제·이용 규칙
    notice/         앱 안 알림 배너
    utils/          한글 초성 검색, 시간 표시
    widgets/        공용 위젯(Pressable, SelectChip, ConfirmDialog, GoogleSignInButton …)
  data/
    models/         Firestore 문서 모델
    demo/           데모 저장소(demo_store.dart)와 더미 데이터·시나리오(demo_seed.dart)
  features/         화면: auth, onboarding, guide, checkin, spot, requests, chat, my, safety, session
docs/               기획 문서
test/               흐름·단위 테스트
```

- **스택**: Flutter, flutter_riverpod 3(`Notifier`), go_router(하단 탭 4개는 `StatefulShellRoute`)
- **라우팅 가드**: `features/session/session.dart`의 세션 상태(로그인·온보딩·정지·체크인)로 화면을 나눕니다.
- **디자인**: 다크 모드가 기본입니다. 색·글꼴·간격은 `AppColors` / `AppTypography` / `AppSpacing` / `AppRadius` 토큰만 씁니다. 숫자 규칙(30자, 40자, 30분 등)은 `AppLimits`에서 가져옵니다.

## 기획 문서

| 문서 | 내용 |
| --- | --- |
| [`docs/BIND_blueprint.md`](docs/BIND_blueprint.md) | 전략, 타겟, 비즈니스 모델, MVP 범위, 위험한 가정 |
| [`docs/BIND_userstory.md`](docs/BIND_userstory.md) | 사용자 스토리 US-001~024와 인수 조건 |
| [`docs/BIND_IA.md`](docs/BIND_IA.md) | 화면 구조와 라우트 매핑 |
| [`docs/DESIGN.md`](docs/DESIGN.md) | 디자인 토큰과 앱 확장 토큰 |

## 남은 일

- **Firebase 연결**: `flutterfire configure`로 `lib/firebase_options.dart`를 만들고, 코드의 `TODO(firebase)` 위치를 Firestore·Cloud Functions 호출로 바꿉니다. 장소 이름 키로 같은 장소 찾기, 신청 만료, 채팅방 생성, 신고 누적 정지는 클라이언트가 아니라 Cloud Functions에서 해야 합니다.
- **로그인**: 구글·애플 실제 로그인과 로그인 상태 유지(지금은 매번 로그인 화면에서 시작)
- **푸시 알림**: FCM으로 신청 도착·수락·만료·새 메시지 알림
- **결제**: BIND+ 구독(현재는 데모 결제)
- **출시 전 법률 검토**: 사용자가 입력한 장소를 저장하는 구조가 위치정보법 적용 대상인지, 양방향 채팅이 부가통신사업 신고 대상인지 확인합니다.
