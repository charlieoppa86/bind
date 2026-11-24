import 'package:bind_app/app/app.dart';
import 'package:bind_app/app/router/app_router.dart';
import 'package:bind_app/app/router/routes.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_seed.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:bind_app/features/spot/presentation/spot_feed_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 피드 카드 높이(2026-11-25): 상태(대화 요청/수락 대기 중/대화 중)·신뢰 표시·하는 일 길이와
/// 상관없이 같고, 이전(170)보다 약 15% 낮다. 주제가 두 줄이거나 그룹 채팅 줄이 있으면 그만큼 커진다.
void main() {
  testWidgets('주제가 한 줄인 카드는 상태와 상관없이 높이가 같다', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 4000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BindApp()),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final store = container.read(demoStoreProvider.notifier)
      ..signIn()
      ..saveDraftProfile('지후', JobTag.developer)
      ..completeOnboarding();
    await tester.pumpAndSettle();
    store.checkIn(
      place: DemoSeed.places[0],
      topic: '카드 높이 확인',
      category: TopicCategory.dev,
      ageBand: AgeBand.thirties,
      gender: Gender.female,
    );
    // 태오에게 요청 → "수락 대기 중"
    final taeo = container
        .read(demoStoreProvider)
        .feed('seongsu', DateTime.now())
        .firstWhere((c) => c.uid == 'u-taeo');
    store.sendRequest(taeo, '안녕하세요');
    container.read(routerProvider).go(Routes.spot);
    await tester.pumpAndSettle();

    double heightOf(String nickname) => tester
        .getSize(
          find.ancestor(
            of: find.text(nickname),
            matching: find.byType(TopicCard),
          ),
        )
        .height;

    final base = heightOf('하린'); // 대화 요청
    expect(heightOf('태오'), base); // 수락 대기 중
    expect(heightOf('유나PM'), base); // 신뢰 표시
    expect(heightOf('재현'), base); // 하는 일이 긴 사람(한 줄로 줄임)
    expect(base, lessThanOrEqualTo(170 * 0.86)); // 이전보다 약 15% 낮게

    await tester.pumpWidget(const SizedBox());
  });
}
