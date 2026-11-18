import 'package:bind_app/core/widgets/apple_sign_in_button.dart';
import 'package:bind_app/core/widgets/google_sign_in_button.dart';
import 'package:bind_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    // 플랫폼을 바꿔 다시 그릴 때 이전 화면을 비우고 새로 만든다.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('Android는 Google 로그인만, iOS의 Google 버튼과 같은 자리에 보인다', (
    tester,
  ) async {
    await pumpLogin(tester, TargetPlatform.iOS);
    final iosGoogle = tester.getTopLeft(find.byType(GoogleSignInButton));

    await pumpLogin(tester, TargetPlatform.android);
    expect(find.byType(GoogleSignInButton), findsOneWidget);
    expect(find.byType(AppleSignInButton), findsNothing);
    expect(tester.getTopLeft(find.byType(GoogleSignInButton)).dy, iosGoogle.dy);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS는 Apple과 Google 로그인이 같은 크기로 보인다', (tester) async {
    await pumpLogin(tester, TargetPlatform.iOS);
    final apple = find.byType(AppleSignInButton);
    final google = find.byType(GoogleSignInButton);
    expect(apple, findsOneWidget);
    expect(google, findsOneWidget);
    expect(tester.getSize(apple), tester.getSize(google));
    // Google 버튼이 위, Apple 버튼이 아래에 온다.
    expect(tester.getTopLeft(google).dy, lessThan(tester.getTopLeft(apple).dy));
    debugDefaultTargetPlatformOverride = null;
  });
}
