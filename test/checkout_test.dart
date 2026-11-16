import 'package:bind_app/app/app.dart';
import 'package:bind_app/app/router/app_router.dart';
import 'package:bind_app/app/router/routes.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('마이 탭에서 연 내 체크인에서 체크아웃하면 스팟 선택으로 간다', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BindApp()),
    );
    await tester.pump(const Duration(milliseconds: 700));
    container.read(demoStoreProvider.notifier)
      ..signIn()
      ..saveDraftProfile('지후', JobTag.developer)
      ..completeOnboarding()
      ..checkIn(placeName: '성수 워크라운지', topic: 't', category: TopicCategory.dev);
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.my);
    await tester.pumpAndSettle();
    container.read(routerProvider).push(Routes.spotMe);
    await tester.pumpAndSettle();
    expect(find.text('내 체크인'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '체크아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '체크아웃').last);
    await tester.pumpAndSettle();
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.checkinSpots,
    );
    expect(find.textContaining('지금 어디에 계세요?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
