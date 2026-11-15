import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 라우터 분기를 결정하는 앱 전역 세션 상태.
enum SessionStatus {
  /// 스플래시: 로그인 상태 확인 중
  unknown,
  signedOut,

  /// 로그인했지만 프로필·동의 미완료
  needsOnboarding,

  /// 서로 다른 3명 신고 누적으로 이용 정지
  suspended,
  ready,
}

class Session {
  const Session({
    this.status = SessionStatus.unknown,
    this.uid,
    this.activeCheckinId,
    this.activeSpotId,
  });

  final SessionStatus status;
  final String? uid;
  final String? activeCheckinId;
  final String? activeSpotId;

  bool get isCheckedIn => activeCheckinId != null;

  Session copyWith({
    SessionStatus? status,
    String? uid,
    String? Function()? activeCheckinId,
    String? Function()? activeSpotId,
  }) => Session(
    status: status ?? this.status,
    uid: uid ?? this.uid,
    activeCheckinId: activeCheckinId != null
        ? activeCheckinId()
        : this.activeCheckinId,
    activeSpotId: activeSpotId != null ? activeSpotId() : this.activeSpotId,
  );
}

/// TODO(firebase): FirebaseAuth.authStateChanges + `users/{uid}` 문서 +
/// 내 활성 체크인 스트림을 구독해 [Session]을 만든다.
/// 지금은 화면 흐름 확인용 로컬 상태 전이만 제공한다.
class SessionController extends Notifier<Session> {
  @override
  Session build() => const Session();

  /// 스플래시에서 호출. 현재는 항상 로그아웃 상태로 시작.
  Future<void> restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(status: SessionStatus.signedOut);
  }

  void signedIn({required String uid, required bool isOnboarded}) {
    state = Session(
      status: isOnboarded ? SessionStatus.ready : SessionStatus.needsOnboarding,
      uid: uid,
    );
  }

  void completeOnboarding() =>
      state = state.copyWith(status: SessionStatus.ready);

  void checkedIn({required String checkinId, required String spotId}) =>
      state = state.copyWith(
        activeCheckinId: () => checkinId,
        activeSpotId: () => spotId,
      );

  void checkedOut() => state = state.copyWith(
    activeCheckinId: () => null,
    activeSpotId: () => null,
  );

  void suspend() => state = state.copyWith(status: SessionStatus.suspended);

  void signOut() => state = const Session(status: SessionStatus.signedOut);
}

final sessionProvider = NotifierProvider<SessionController, Session>(
  SessionController.new,
);
