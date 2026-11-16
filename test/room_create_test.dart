import 'package:bind_app/app/app.dart';
import 'package:bind_app/app/router/app_router.dart';
import 'package:bind_app/app/router/routes.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('검색해서 고른 새 장소는 새로 열리고 바로 그 장소 피드로 간다', (tester) async {
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

    // 장소 검색 → 결과에서 아직 아무도 없는 장소를 고른다
    await tester.enterText(find.byType(TextField).first, '루프탑');
    // 디바운스 + 검색 응답: 여러 프레임에 걸쳐 시간을 흘린다
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('장소 정보 제공: 카카오'), findsOneWidget);
    await tester.tap(find.text('성수 루프탑 카페'));
    await tester.pump();
    expect(find.textContaining('처음으로 체크인해요'), findsOneWidget);

    await tester.tap(find.text('개발').first);
    await tester.enterText(find.byType(TextField).last, '루프탑에서 개발 얘기해요');
    await tester.pump();
    await tester.tap(find.text('체크인하기'));
    await tester.pumpAndSettle();

    expect(find.text('성수 루프탑 카페'), findsOneWidget);
    expect(find.text('아직 아무도 없어요'), findsOneWidget);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.spot,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
