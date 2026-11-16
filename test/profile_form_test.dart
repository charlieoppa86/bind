import 'package:bind_app/app/theme/app_theme.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/features/onboarding/presentation/profile_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('기타를 누르면 직접 입력칸이 열리고, 입력해야 다음으로 갈 수 있다', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    (String, JobTag, String?)? submitted;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ProfileForm(
              submitLabel: '다음',
              onSubmit: (n, t, c) => submitted = (n, t, c),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '지후');
    expect(find.byKey(const Key('job-custom-field')), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('기타'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('기타'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-custom-field')), findsOneWidget);

    // 비어 있으면 다음 버튼이 눌리지 않는다
    await tester.tap(find.text('다음'));
    expect(submitted, isNull);

    await tester.enterText(find.byKey(const Key('job-custom-field')), '바리스타');
    await tester.pump();
    await tester.tap(find.text('다음'));
    expect(submitted, ('지후', JobTag.other, '바리스타'));
  });
}
