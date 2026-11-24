import 'package:bind_app/app/app.dart';
import 'package:bind_app/app/theme/app_spacing.dart';
import 'package:bind_app/core/constants/brand.dart';
import 'package:bind_app/core/widgets/bind_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 흐름을 돌려 볼 기기(세로, 논리 픽셀). 아이패드는 [AppSpacing.maxContentWidth]
/// 너비의 가운데 열에 그려진다.
const _devices = [
  (name: '폰', size: Size(360, 780), dpr: 3.0),
  (name: 'iPad Air 11" M4', size: Size(820, 1180), dpr: 2.0),
  (name: 'iPad Pro 13" M4', size: Size(1032, 1376), dpr: 2.0),
];

void main() {
  for (final device in _devices) {
    testWidgets('${device.name}: 로그인 → 온보딩 → 체크인 → 피드 → 요청 → 수락 → 채팅', (
      tester,
    ) async {
      await _runFlow(tester, device.size, device.dpr);
    });
  }
}

Future<void> _runFlow(WidgetTester tester, Size size, double dpr) async {
  tester.view
    ..physicalSize = size * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: BindApp()));
  expect(find.byType(BindLogo), findsOneWidget);

  // 화면은 기기 너비를 넘지 않는 최대 너비 열로, 가운데에 그려진다
  final columnWidth = size.width.clamp(0.0, AppSpacing.maxContentWidth);
  final navigator = find.byType(Navigator).first;
  expect(tester.getSize(navigator).width, columnWidth);
  expect(tester.getCenter(navigator).dx, size.width / 2);

  // 스플래시 → 로그인
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  expect(find.text(Brand.sloganTwoLines), findsOneWidget); // 첫 화면 슬로건
  expect(find.text(Brand.startCall), findsOneWidget); // 그 아래 설명
  await tester.tap(find.text('Google로 로그인'));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();

  // 온보딩 1: 프로필 — 이미 쓰는 닉네임은 다음을 누르면 안내하고 넘어가지 않는다
  expect(find.text('닉네임을 설정하세요'), findsOneWidget);
  await tester.enterText(find.byType(TextField), '도윤');
  await tester.tap(find.text('개발'));
  await tester.pump();
  await tester.tap(find.text('다음'));
  await tester.pumpAndSettle();
  expect(find.text('이미 쓰고 있는 닉네임이에요'), findsOneWidget);
  expect(find.text('닉네임을 설정하세요'), findsOneWidget);
  await tester.enterText(find.byType(TextField), '지후');
  await tester.pumpAndSettle(); // 오류 문구가 사라지는 애니메이션까지
  expect(find.text('이미 쓰고 있는 닉네임이에요'), findsNothing);
  await tester.tap(find.text('다음'));
  await tester.pumpAndSettle();

  // 온보딩 2: 연령·규칙 동의
  await tester.tap(find.text('만 19세 이상이에요'));
  await tester.pump();
  await tester.tap(find.text('이용 규칙에 모두 동의해요'));
  await tester.pump();
  await tester.tap(find.text('동의하고 가입 완료'));
  await tester.pumpAndSettle();

  // 사용법 가이드 → 스팟 선택
  await tester.tap(find.text('건너뛰기'));
  await tester.pumpAndSettle();
  // 체크인: 장소 검색 → 결과에서 고르기(사람 있는 곳은 인원 표시) → 주제 → 체크인
  expect(find.text('지후님,\n지금 어디에 계세요?'), findsOneWidget);
  final fields = find.byType(TextField);
  await tester.enterText(fields.first, '워크라');
  // 디바운스 + 검색 응답: 여러 프레임에 걸쳐 시간을 흘린다
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.textContaining('지금 '), findsWidgets);
  await tester.tap(find.text('성수 워크라운지').last);
  await tester.pump();
  expect(find.textContaining('같은 곳으로 들어가요'), findsOneWidget);

  // 장소 → 대화 방식 → 주제 → 키워드 순서. 키워드는 아래에 있어 내려서 고른다.
  await tester.enterText(find.byType(TextField).last, 'Flutter 상태관리 같이 고민해요');
  await tester.pump();
  await tester.dragUntilVisible(
    find.text('개발'),
    find.byType(ListView).first,
    const Offset(0, -200),
  );
  await tester.tap(find.text('개발').first);
  await tester.pump();
  // 연령대·성별(필수)도 아래에 있어 내려서 고른다.
  await tester.dragUntilVisible(
    find.text('여성'),
    find.byType(ListView).first,
    const Offset(0, -200),
  );
  await tester.tap(find.text('30대'));
  await tester.tap(find.text('여성'));
  await tester.pump();
  await tester.tap(find.text('체크인하기'));
  await tester.pumpAndSettle();

  // 스팟 피드: 같은 스팟 사람들의 카드
  expect(find.text('성수 워크라운지'), findsOneWidget);
  // 데모 장소의 9명 + 나 = 10명 → 나를 뺀 9명만 보인다
  expect(find.text('지금 9명이 같은 장소에 있어요'), findsOneWidget);
  expect(find.byType(BindMark), findsOneWidget); // AppBar 왼쪽 마크
  expect(find.text('PM 커리어 피벗 얘기 나눠요'), findsOneWidget);

  // 대화 요청
  await tester.tap(find.text('MVP 검증 어떻게 하셨어요'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '저도 MVP 검증 중이에요!');
  await tester.pump();
  await tester.tap(find.text('대화 요청하기'));
  await tester.pumpAndSettle();
  expect(find.text('수락 대기 중'), findsOneWidget);

  // 몇 초 뒤: 상대가 수락하고, 다른 사람이 나에게 요청을 보낸다
  await tester.pump(const Duration(seconds: 8));
  await tester.pumpAndSettle();

  // 받은 요청 수락 → 대화방
  await tester.tap(find.text('요청').last);
  await tester.pumpAndSettle();
  expect(find.text('저도 같은 고민 중이라 얘기 나눠보고 싶어요!'), findsOneWidget);
  await tester.tap(find.text('저도 같은 고민 중이라 얘기 나눠보고 싶어요!'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('수락하고 대화 시작'));
  await tester.pumpAndSettle();
  expect(find.text('대화 요청이 수락되어 1:1 채팅이 시작됐어요'), findsOneWidget);
  // 대화방 보관 기간 제한이 없다(2026-11-23)
  expect(find.textContaining('사라집니다'), findsNothing);

  // 메시지 보내기 → 답장
  await tester.enterText(find.byType(TextField), '안녕하세요!');
  await tester.pump();
  await tester.tap(find.byTooltip('보내기'));
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  expect(find.text('안녕하세요!'), findsOneWidget);
  expect(find.text('오 저도 그거 궁금했어요. 어떻게 하고 계세요?'), findsOneWidget);

  // 나가면 평가 → 대화 목록
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text('좋았어요'));
  await tester.pumpAndSettle();
  expect(find.text('재현'), findsOneWidget); // 수락된 내 요청의 대화방
  expect(find.text('떠난 사용자'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
}
