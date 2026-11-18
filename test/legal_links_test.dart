import 'package:bind_app/core/links/app_links.dart';
import 'package:bind_app/features/auth/presentation/login_screen.dart';
import 'package:bind_app/features/safety/presentation/suspended_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late List<Uri> opened;

  Widget app(Widget home) => ProviderScope(
    overrides: [
      linkOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
    child: MaterialApp(home: home),
  );

  setUp(() => opened = []);

  testWidgets('로그인 화면의 이용약관·개인정보 처리방침을 누르면 각 페이지가 열린다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen()));
    await tester.tap(find.text('이용약관'));
    await tester.tap(find.text('개인정보 처리방침'));
    expect(opened, [AppLinks.terms, AppLinks.privacy]);
  });

  testWidgets('정지 화면은 문의 이메일을 보여 주고 이의 제기 메일을 연다', (tester) async {
    await tester.pumpWidget(app(const SuspendedScreen()));
    expect(find.text(AppLinks.supportEmail), findsOneWidget);
    expect(find.textContaining('고객센터'), findsNothing);
    await tester.tap(find.text('이의 제기 메일 보내기'));
    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, AppLinks.supportEmail);
  });

  test('문의 메일 제목은 인코딩되어 들어간다', () {
    final uri = AppLinks.supportMail(subject: '[BIND] 문의');
    expect(uri.toString(), startsWith('mailto:${AppLinks.supportEmail}?subject='));
    expect(Uri.decodeComponent(uri.query.split('=').last), '[BIND] 문의');
  });
}
