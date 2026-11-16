import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 라우터 분기를 결정하는 앱 전역 세션 상태.
enum SessionStatus {
  /// 스플래시: 로그인 상태 확인 중
  unknown,
  signedOut,

  /// 로그인했지만 프로필·동의 미완료
  needsOnboarding,

  /// 서로 다른 신고자 `AppLimits.reportsUntilSuspension`명 누적으로 이용 정지
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

/// 라우터 가드가 보는 세션. 로그인·온보딩은 `AccountController`가,
/// 체크인 상태는 데모 저장소가 갱신한다.
/// TODO(firebase 2단계): 내 활성 체크인을 Firestore 스트림으로 구독한다.
class SessionController extends Notifier<Session> {
  @override
  Session build() => const Session();

  /// 로그인 완료. 같은 사람이면 먼저 불러 둔 체크인 상태는 그대로 둔다
  /// (앱을 다시 켰을 때 체크인 중이면 바로 피드로 가도록).
  void signedIn({required String uid, required bool isOnboarded}) {
    final keep = state.uid == null || state.uid == uid;
    state = Session(
      status: isOnboarded ? SessionStatus.ready : SessionStatus.needsOnboarding,
      uid: uid,
      activeCheckinId: keep ? state.activeCheckinId : null,
      activeSpotId: keep ? state.activeSpotId : null,
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
