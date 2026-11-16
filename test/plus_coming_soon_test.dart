import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:bind_app/features/my/presentation/my_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('BIND+ 시작하기를 누르면 준비 중 팝업이 뜨고 확인으로 닫힌다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(demoStoreProvider.notifier)
      ..signIn()
      ..saveDraftProfile('지후', JobTag.developer)
      ..completeOnboarding();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.tap(find.text('BIND+ 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('BIND+는 준비 중입니다.'), findsOneWidget);
    expect(find.text('취소'), findsNothing); // 확인 버튼 하나만

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('BIND+는 준비 중입니다.'), findsNothing);
  });
}
