import 'package:bind_app/app/router/app_router.dart';
import 'package:bind_app/app/router/routes.dart';
import 'package:bind_app/features/session/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sessionRedirect', () {
    test('확인 중이면 스플래시로', () {
      expect(sessionRedirect(const Session(), Routes.my), Routes.splash);
    });

    test('로그아웃 상태면 로그인으로', () {
      const s = Session(status: SessionStatus.signedOut);
      expect(sessionRedirect(s, Routes.chats), Routes.login);
      expect(sessionRedirect(s, Routes.login), isNull);
    });

    test('정지 계정은 모든 경로에서 정지 안내로', () {
      const s = Session(status: SessionStatus.suspended);
      expect(sessionRedirect(s, Routes.spot), Routes.suspended);
      expect(sessionRedirect(s, Routes.myAccount), Routes.suspended);
    });

    test('온보딩 미완료면 온보딩만 허용', () {
      const s = Session(status: SessionStatus.needsOnboarding);
      expect(sessionRedirect(s, Routes.spot), Routes.onboardingProfile);
      expect(sessionRedirect(s, Routes.onboardingConsent), isNull);
    });

    test('체크인 전에는 스팟 탭 대신 체크인 흐름', () {
      const s = Session(status: SessionStatus.ready);
      expect(sessionRedirect(s, Routes.login), Routes.checkinSpots);
      expect(sessionRedirect(s, Routes.spot), Routes.checkinSpots);
      expect(sessionRedirect(s, Routes.spotMe), Routes.checkinSpots);
      expect(sessionRedirect(s, Routes.chats), isNull);
    });

    test('체크인 후에는 스팟 피드가 홈', () {
      const s = Session(
        status: SessionStatus.ready,
        activeCheckinId: 'c1',
        activeSpotId: 's1',
      );
      expect(sessionRedirect(s, Routes.splash), Routes.spot);
      expect(sessionRedirect(s, Routes.spot), isNull);
      expect(sessionRedirect(s, Routes.onboardingGuide), isNull);
    });
  });
}
