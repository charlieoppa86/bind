import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/account/account_repository.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:bind_app/data/models/app_user.dart';
import 'package:bind_app/features/session/account_controller.dart';
import 'package:bind_app/features/session/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase 대신 쓰는 가짜 계정 저장소(서버 동작 흉내)
class FakeAccountRepository implements AccountRepository {
  String? signedInUid;
  String? nextSignInUid = 'uid-1';
  final profiles = <String, AppUser>{};
  final nicknames = <String, String>{}; // key → uid

  @override
  Future<String?> restoreUid() async => signedInUid;

  @override
  Future<String?> signIn() async => signedInUid = nextSignInUid;

  String? nextAppleUid = 'apple-1';

  @override
  Future<String?> signInWithApple() async => signedInUid = nextAppleUid;

  @override
  Future<AppUser?> loadProfile(String uid) async => profiles[uid];

  @override
  Future<bool> isNicknameTaken(String uid, String nickname) async {
    final owner = nicknames[nicknameKey(nickname)];
    return owner != null && owner != uid;
  }

  @override
  Future<void> createProfile(AppUser user) async {
    if (await isNicknameTaken(user.uid, user.nickname)) {
      throw const NicknameTakenException();
    }
    nicknames[nicknameKey(user.nickname)] = user.uid;
    profiles[user.uid] = user;
  }

  @override
  Future<void> updateProfile(
    String uid, {
    required String oldNickname,
    required String nickname,
    required JobTag jobTag,
    String? jobCustom,
  }) async {}

  @override
  Future<void> markGuideSeen(String uid) async {}

  @override
  Future<void> signOut() async => signedInUid = null;

  /// 탈퇴 전 Apple 확인 창을 닫는 상황
  bool cancelRevoke = false;
  bool deleted = false;

  @override
  Future<void> revokeForDeletion() async {
    if (cancelRevoke) throw const AuthCanceledException();
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    signedInUid = null;
  }
}

void main() {
  late FakeAccountRepository repo;
  late ProviderContainer container;
  AccountController account() => container.read(accountProvider);
  Session session() => container.read(sessionProvider);

  setUp(() {
    repo = FakeAccountRepository();
    container = ProviderContainer(
      overrides: [accountRepositoryProvider.overrideWithValue(repo)],
    );
  });
  tearDown(() => container.dispose());

  test('닉네임 키는 공백·대소문자를 무시한다', () {
    expect(nicknameKey(' Ji Hoo '), nicknameKey('jihoo'));
  });

  test('로그인을 취소하면 로그아웃 상태 그대로다', () async {
    await account().restore();
    repo.nextSignInUid = null;
    expect(await account().signIn(), isFalse);
    expect(session().status, SessionStatus.signedOut);
  });

  test('처음 로그인하면 온보딩, 가입을 마치면 서버에 프로필이 생긴다', () async {
    expect(await account().signIn(), isTrue);
    expect(session().status, SessionStatus.needsOnboarding);
    expect(session().uid, 'uid-1');

    container
        .read(demoStoreProvider.notifier)
        .saveDraftProfile('지후', JobTag.developer);
    await account().completeOnboarding();
    expect(repo.profiles['uid-1']?.nickname, '지후');
    expect(session().status, SessionStatus.ready);
  });

  test('가입 사이 다른 사람이 닉네임을 가져가면 저장하지 않는다', () async {
    await account().signIn();
    repo.nicknames[nicknameKey('지후')] = 'someone-else';
    expect(await account().isNicknameTaken('지 후'), isTrue);

    container
        .read(demoStoreProvider.notifier)
        .saveDraftProfile('지후', JobTag.developer);
    await expectLater(
      account().completeOnboarding(),
      throwsA(isA<NicknameTakenException>()),
    );
    expect(container.read(demoStoreProvider).me, isNull);
    expect(session().status, SessionStatus.needsOnboarding);
  });

  test('다시 켜면 저장된 프로필로 바로 들어가고, 로그아웃하면 프로필이 비워진다', () async {
    repo
      ..signedInUid = 'uid-9'
      ..profiles['uid-9'] = AppUser(
        uid: 'uid-9',
        nickname: '하린',
        jobTag: JobTag.freelancer,
        consentedAt: DateTime(2026),
      );
    await account().restore();
    expect(session().status, SessionStatus.ready);
    expect(container.read(demoStoreProvider).me?.nickname, '하린');

    await account().signOut();
    expect(session().status, SessionStatus.signedOut);
    expect(container.read(demoStoreProvider).me, isNull);
  });

  test('Apple로 로그인해도 같은 온보딩으로 들어간다', () async {
    expect(await account().signInWithApple(), isTrue);
    expect(session().status, SessionStatus.needsOnboarding);
    expect(session().uid, 'apple-1');
  });

  test('Apple 로그인 창을 닫으면 로그아웃 상태 그대로다', () async {
    await account().restore();
    repo.nextAppleUid = null;
    expect(await account().signInWithApple(), isFalse);
    expect(session().status, SessionStatus.signedOut);
  });

  Future<void> signUp() async {
    await account().signInWithApple();
    container
        .read(demoStoreProvider.notifier)
        .saveDraftProfile('지후', JobTag.developer);
    await account().completeOnboarding();
  }

  test('탈퇴 중 Apple 확인 창을 닫으면 아무것도 지우지 않는다', () async {
    await signUp();
    repo.cancelRevoke = true;
    await expectLater(
      account().deleteAccount(),
      throwsA(isA<AuthCanceledException>()),
    );
    expect(repo.deleted, isFalse);
    expect(session().status, SessionStatus.ready);
    expect(container.read(demoStoreProvider).me?.nickname, '지후');
  });

  test('Apple 확인 뒤에는 탈퇴가 끝까지 진행된다', () async {
    await signUp();
    await account().deleteAccount();
    expect(repo.deleted, isTrue);
    expect(session().status, SessionStatus.signedOut);
  });
}
