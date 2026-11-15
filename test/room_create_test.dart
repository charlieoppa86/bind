import 'package:bind_app/app/app.dart';
import 'package:bind_app/app/router/app_router.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/core/location/location.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_location.dart';

void main() {
  testWidgets('주변에 방을 열면 개설자에게만 PIN이 보이고, 바로 입장한다', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
    );
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

    await tester.tap(find.text('이 근처에 새 방 열기'));
    await tester.pumpAndSettle();
    expect(find.text('어디에 방을 열까요?'), findsOneWidget);
    // 200m 밖 장소는 열 수 없다
    expect(find.text('200m 밖'), findsWidgets);

    await tester.tap(find.text('성수 카페거리 루프탑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('방 열고 PIN 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('방이 열렸어요!\n입장 PIN을 알려주세요'), findsOneWidget);
    final db = container.read(demoStoreProvider);
    final room = db.spots.last;
    expect(db.isCreator(room.id), isTrue);
    for (final d in db.spotCodes[room.id]!.split('')) {
      expect(find.text(d), findsWidgets);
    }

    await tester.tap(find.text('내 주제 정하고 입장하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개발').first);
    await tester.enterText(find.byType(TextField), '루프탑에서 개발 얘기해요');
    await tester.pump();
    await tester.tap(find.text('체크인하기'));
    await tester.pumpAndSettle();

    expect(find.text('성수 카페거리 루프탑'), findsOneWidget);
    expect(find.text('입장 PIN'), findsOneWidget);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/spot',
    );

    await tester.pumpWidget(const SizedBox());
  });
}
