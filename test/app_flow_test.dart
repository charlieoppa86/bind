import 'package:bind_app/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('로그인 → 온보딩 → 체크인 → 피드 → 신청 → 수락 → 채팅', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: BindApp()));
    expect(find.text('BIND'), findsOneWidget);

    // 스플래시 → 로그인
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google로 로그인'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // 온보딩 1: 프로필 — 이미 쓰는 닉네임은 바로 안내
    expect(find.text('닉네임을 설정하세요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '도윤');
    await tester.pump();
    expect(find.text('이미 쓰고 있는 닉네임이에요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '지후');
    await tester.tap(find.text('개발'));
    await tester.pump();
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
    // 체크인: 장소를 자유롭게 입력 → 이미 있는 장소 추천 → 주제 → 체크인
    expect(find.text('지후님,\n지금 어디에 계세요?'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '워크라');
    await tester.pump();
    expect(find.text('혹시 이 장소인가요?'), findsOneWidget);
    await tester.tap(find.text('성수 워크라운지').last);
    await tester.pump();
    expect(find.textContaining('같은 곳으로 들어가요'), findsOneWidget);

    await tester.tap(find.text('개발').first);
    await tester.pump();
    await tester.enterText(fields.last, 'Flutter 상태관리 같이 고민해요');
    await tester.pump();
    await tester.tap(find.text('체크인하기'));
    await tester.pumpAndSettle();

    // 스팟 피드: 같은 스팟 사람들의 카드
    expect(find.text('성수 워크라운지'), findsOneWidget);
    expect(find.text('PM 커리어 피벗 얘기 나눠요'), findsOneWidget);

    // 대화 신청
    await tester.tap(find.text('MVP 검증 어떻게 하셨어요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '저도 MVP 검증 중이에요!');
    await tester.pump();
    await tester.tap(find.text('신청 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('답을 기다리는 중'), findsOneWidget);

    // 몇 초 뒤: 상대가 수락하고, 다른 사람이 나에게 신청을 보낸다
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    // 받은 신청 수락 → 대화방
    await tester.tap(find.text('신청함'));
    await tester.pumpAndSettle();
    expect(find.text('저도 같은 고민 중이라 얘기 나눠보고 싶어요!'), findsOneWidget);
    await tester.tap(find.text('저도 같은 고민 중이라 얘기 나눠보고 싶어요!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수락하고 대화하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('일 뒤 대화가 사라집니다'), findsOneWidget);

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
    expect(find.text('재현'), findsOneWidget); // 수락된 내 신청의 대화방
    expect(find.text('떠난 사용자'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
