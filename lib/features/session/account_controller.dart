import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/account/account_repository.dart';
import '../../data/demo/demo_store.dart';
import 'session.dart';

/// 로그인·온보딩·프로필 수정·로그아웃·탈퇴의 진입점.
///
/// 계정 저장소(Firebase 또는 데모)에 먼저 쓰고, 성공하면 앱 안 상태
/// (데모 저장소의 내 프로필, 세션)를 맞춘다. 화면은 이것만 부른다.
/// 체크인·요청·채팅은 아직 데모 저장소를 쓴다(2단계에서 Firestore로 옮김).
class AccountController {
  AccountController(this._ref);

  final Ref _ref;

  AccountRepository get _repo => _ref.read(accountRepositoryProvider);
  DemoStore get _store => _ref.read(demoStoreProvider.notifier);
  SessionController get _session => _ref.read(sessionProvider.notifier);
  String get _uid => _ref.read(sessionProvider).uid ?? '';

  /// 데모 저장소는 로그아웃해도 내 프로필을 남겨 다시 들어올 수 있게 한다.
  bool get _isDemo => _repo is DemoAccountRepository;

  /// 스플래시: 로그인돼 있던 사용자면 프로필을 불러와 들어간다.
  Future<void> restore() async {
    final uid = await _repo.restoreUid();
    if (uid == null) {
      _session.signOut();
      return;
    }
    await _enter(uid);
  }

  /// Google 로그인. 사용자가 취소하면 false.
  Future<bool> signIn() async {
    final uid = await _repo.signIn();
    if (uid == null) return false;
    await _enter(uid);
    return true;
  }

  Future<void> _enter(String uid) async {
    final profile = await _repo.loadProfile(uid);
    if (!_isDemo) _store.enter(profile);
    final onboarded = _ref.read(demoStoreProvider).me != null;
    _session.signedIn(uid: uid, isOnboarded: onboarded);
    if (profile?.suspended ?? false) _session.suspend();
  }

  /// 데모 저장소에 있는 닉네임 + 서버의 닉네임 예약을 함께 본다.
  Future<bool> isNicknameTaken(String nickname) async =>
      _store.isNicknameTaken(nickname) ||
      await _repo.isNicknameTaken(_uid, nickname);

  /// 온보딩 완료. 그 사이 다른 사람이 닉네임을 가져갔으면 [NicknameTakenException].
  Future<void> completeOnboarding() async {
    final draft = _store.draftUser(_uid);
    await _repo.createProfile(draft);
    _store.completeOnboarding();
  }

  Future<void> updateProfile(
    String nickname,
    JobTag jobTag, {
    String? jobCustom,
  }) async {
    final old = _ref.read(demoStoreProvider).me?.nickname ?? '';
    await _repo.updateProfile(
      _uid,
      oldNickname: old,
      nickname: nickname.trim(),
      jobTag: jobTag,
      jobCustom: jobCustom?.trim(),
    );
    _store.updateProfile(nickname, jobTag, jobCustom: jobCustom);
  }

  Future<void> markGuideSeen() async {
    _store.markGuideSeen();
    await _repo.markGuideSeen(_uid);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    if (!_isDemo) _store.enter(null);
    _store.signOut();
  }

  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    _store.deleteAccount();
  }
}

final accountProvider = Provider<AccountController>(AccountController.new);
