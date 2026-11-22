import 'package:bind_app/app/app.dart';
import 'package:bind_app/app/router/app_router.dart';
import 'package:bind_app/core/constants/app_limits.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_seed.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// US-025 그룹 채팅: 체크인할 때 열기 / 피드 카드에서 참여 / 1:1과 구분되는 표시
void main() {
  const group = '그룹 채팅';
  const max = AppLimits.groupChatMaxMembers;

  Future<ProviderContainer> start(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BindApp()),
    );
    await tester.pump(const Duration(milliseconds: 700));
    container.read(demoStoreProvider.notifier)
      ..signIn()
      ..saveDraftProfile('지후', JobTag.developer)
      ..completeOnboarding();
    await tester.pumpAndSettle();
    return container;
  }

  /// 성수 워크라운지에 체크인한다. [openGroup]이면 "그룹 채팅도 열기"를 켠다.
  Future<void> checkIn(
    WidgetTester tester, {
    required String topic,
    bool openGroup = false,
  }) async {
    await tester.enterText(find.byType(TextField).first, '워크라');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('성수 워크라운지').last);
    await tester.pump();
    await tester.tap(find.text('개발').first);
    await tester.enterText(find.byType(TextField).last, topic);
    await tester.pump();
    // 키워드 아래 "대화 방식"까지 내려 본다(지연 생성 목록)
    await tester.dragUntilVisible(
      find.text('$group도 열기'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('끄면 1:1 채팅 요청만 받아요.'), findsOneWidget);
    if (openGroup) {
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.textContaining('요청 없이 바로 들어와'), findsOneWidget);
    }
    await tester.tap(find.text('체크인하기'));
    await tester.pumpAndSettle();
  }

  testWidgets('체크인할 때 그룹 채팅을 열면 내 체크인·채팅 목록·대화방에서 그룹 채팅으로 보인다', (tester) async {
    final container = await start(tester);
    final router = container.read(routerProvider);
    await checkIn(tester, topic: 'Flutter 같이 얘기해요', openGroup: true);

    // 내 체크인: 연 그룹 채팅과 인원
    await tester.tap(find.text('체크인 관리'));
    await tester.pumpAndSettle();
    expect(find.text('$group · 1/$max명 · 참여 중'), findsOneWidget);
    expect(find.text('들어가기'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    // 몇 초 뒤 같은 장소 사람이 들어와 인사한다
    await tester.pump(DemoSeed.groupJoiners.first.$3);
    await tester.pumpAndSettle();
    expect(find.text('민서디자인님이 그룹 채팅에 들어왔어요'), findsOneWidget);

    // 채팅 목록: 방 이름은 주제, 종류 표시는 그룹(1:1 방은 1:1로)
    await tester.tap(find.text('채팅').last);
    await tester.pumpAndSettle();
    expect(find.text('Flutter 같이 얘기해요'), findsOneWidget);
    expect(find.text('$group · 2명'), findsOneWidget);
    expect(find.text('1:1 채팅'), findsWidgets);

    // 대화방: 머리에 그룹 채팅·인원, 다른 사람 말풍선 위에 이름
    await tester.tap(find.text('Flutter 같이 얘기해요'));
    await tester.pumpAndSettle();
    expect(find.text('$group · 2명'), findsOneWidget);
    expect(find.text('체크인한 주제로 $group이 열렸어요'), findsOneWidget);
    expect(find.text('민서디자인'), findsOneWidget);
    expect(find.text(DemoSeed.groupJoiners.first.$2), findsOneWidget);

    // 내가 보내면 남은 사람이 답한다. 나갈 때 평가는 묻지 않는다.
    await tester.enterText(find.byType(TextField), '반가워요!');
    await tester.pump();
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump(DemoSeed.replyDelay);
    await tester.pumpAndSettle();
    expect(find.text('반가워요!'), findsOneWidget);
    expect(find.text(DemoSeed.replies.first), findsOneWidget);
    // 앱이 한국어라 pageBack()이 찾는 'Back' 툴팁이 없다. 뒤로 버튼을 직접 누른다.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('좋았어요'), findsNothing);
    expect(find.text('Flutter 같이 얘기해요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('피드 카드의 그룹 채팅에 참여하고, 참여자 시트에서 나간다', (tester) async {
    await start(tester);
    await checkIn(tester, topic: '사이드 프로젝트 얘기해요');

    // 피드: 그룹 채팅이 열린 카드에만 표시
    const topic = '사이드 프로젝트 같이 고민해요';
    await tester.dragUntilVisible(
      find.text(topic),
      find.byType(CustomScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('$group · 3/$max명'), findsOneWidget);

    // 시트: 그룹 참여 + 1:1 요청을 고를 수 있다
    await tester.tap(find.text(topic));
    await tester.pumpAndSettle();
    expect(find.text('$group 참여하기'), findsOneWidget);
    expect(find.text('1:1 채팅으로 이야기하고 싶다면'), findsOneWidget);
    expect(find.text('1:1 채팅 요청하기'), findsOneWidget);

    await tester.tap(find.text('$group 참여하기'));
    await tester.pumpAndSettle();
    expect(find.text(topic), findsOneWidget); // 방 이름
    expect(find.text('$group · 4명'), findsOneWidget);
    expect(find.text('사이드 프로젝트 하시는 분들 편하게 얘기해요!'), findsOneWidget);
    expect(find.text('하나'), findsOneWidget); // 보낸 사람 이름
    await tester.pump(DemoSeed.replyDelay);
    await tester.pumpAndSettle();
    expect(find.text(DemoSeed.groupWelcome), findsOneWidget);

    // 참여자: 연 사람·나 표시, 나가기 → 확인 → 목록에서 사라진다
    await tester.tap(find.byTooltip('참여자'));
    await tester.pumpAndSettle();
    expect(find.text('참여자 4/$max명'), findsOneWidget);
    expect(find.text('연 사람'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    await tester.tap(find.text('$group 나가기'));
    await tester.pumpAndSettle();
    expect(find.text('$group에서 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text(topic), findsNothing);
    expect(find.text('1:1 채팅'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });
}
