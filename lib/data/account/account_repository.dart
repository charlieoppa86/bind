import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/enums.dart';
import '../../firebase_options.dart';
import '../models/app_user.dart';
import '../place/place_search.dart';

/// 닉네임 중복 판정 키: 앞뒤 공백·중간 공백 제거, 소문자.
/// `nicknames/{key}` 문서 id로 써서 같은 닉네임을 한 사람만 갖게 한다.
String nicknameKey(String nickname) =>
    nickname.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 다른 사람이 이미 쓰는 닉네임으로 저장하려 할 때
class NicknameTakenException implements Exception {
  const NicknameTakenException();
}

/// 기기에 로그인된 Google 계정이 없을 때(Android Credential Manager)
class NoGoogleAccountException implements Exception {
  const NoGoogleAccountException();
}

/// 로그인·내 프로필(users/{uid}) 저장소.
///
/// - [FirebaseAccountRepository]: Google 로그인 + Firestore
/// - [DemoAccountRepository]: Firebase 없이 화면 흐름 확인용
abstract interface class AccountRepository {
  /// 앱을 다시 켰을 때 로그인돼 있던 사용자 uid(없으면 null)
  Future<String?> restoreUid();

  /// Google 로그인. 사용자가 취소하면 null.
  Future<String?> signIn();

  /// 내 프로필. 아직 온보딩을 안 했으면 null.
  Future<AppUser?> loadProfile(String uid);

  Future<bool> isNicknameTaken(String uid, String nickname);

  /// 온보딩 완료: 닉네임 예약 + users 문서 생성(한 트랜잭션)
  /// 닉네임이 이미 있으면 [NicknameTakenException].
  Future<void> createProfile(AppUser user);

  /// 프로필 수정. 닉네임이 바뀌면 예약도 옮긴다.
  Future<void> updateProfile(
    String uid, {
    required String oldNickname,
    required String nickname,
    required JobTag jobTag,
    String? jobCustom,
  });

  Future<void> markGuideSeen(String uid);

  Future<void> signOut();

  /// 탈퇴: 서버(Functions)가 닉네임 해제·프로필 삭제 표시·계정 삭제를 한다.
  Future<void> deleteAccount();
}

class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: FunctionsPlaceSearch.region);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final _google = GoogleSignIn.instance;
  Future<void>? _googleReady;

  /// google_sign_in 7은 initialize를 딱 한 번 불러야 한다.
  /// Android는 google-services.json의 웹 클라이언트 ID를 자동으로 쓰고,
  /// iOS는 GoogleService-Info.plist의 iOS 클라이언트 ID를 넘긴다.
  Future<void> _initGoogle() => _googleReady ??= _google.initialize(
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? DefaultFirebaseOptions.ios.iosClientId
        : null,
  );

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _nickname(String nickname) =>
      _db.collection('nicknames').doc(nicknameKey(nickname));

  @override
  Future<String?> restoreUid() async {
    // 앱 시작 직후에는 저장된 로그인 정보를 읽는 중일 수 있어 첫 상태를 기다린다.
    final user = await _auth.authStateChanges().first;
    return user?.uid;
  }

  @override
  Future<String?> signIn() async {
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      if ('${e.description}'.contains('No credential')) {
        throw const NoGoogleAccountException();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    final result = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return result.user?.uid;
  }

  @override
  Future<AppUser?> loadProfile(String uid) async {
    final snap = await _user(uid).get();
    final data = snap.data();
    if (data == null) return null;
    final user = AppUser.fromMap(uid, data);
    return user.isOnboarded ? user : null;
  }

  @override
  Future<bool> isNicknameTaken(String uid, String nickname) async {
    final snap = await _nickname(nickname).get();
    return snap.exists && snap.data()?['uid'] != uid;
  }

  @override
  Future<void> createProfile(AppUser user) => _db.runTransaction((tx) async {
    final nickRef = _nickname(user.nickname);
    final nick = await tx.get(nickRef);
    if (nick.exists && nick.data()?['uid'] != user.uid) {
      throw const NicknameTakenException();
    }
    tx
      ..set(nickRef, {'uid': user.uid})
      ..set(_user(user.uid), {
        ...user.toMap(),
        'nicknameKey': nicknameKey(user.nickname),
        'consentedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
  });

  @override
  Future<void> updateProfile(
    String uid, {
    required String oldNickname,
    required String nickname,
    required JobTag jobTag,
    String? jobCustom,
  }) => _db.runTransaction((tx) async {
    final changed = nicknameKey(oldNickname) != nicknameKey(nickname);
    if (changed) {
      final newRef = _nickname(nickname);
      final taken = await tx.get(newRef);
      if (taken.exists && taken.data()?['uid'] != uid) {
        throw const NicknameTakenException();
      }
      tx
        ..set(newRef, {'uid': uid})
        ..delete(_nickname(oldNickname));
    }
    tx.update(_user(uid), {
      'nickname': nickname,
      'nicknameKey': nicknameKey(nickname),
      'jobTag': jobTag.name,
      'jobCustom': jobTag == JobTag.other ? jobCustom : null,
    });
  });

  @override
  Future<void> markGuideSeen(String uid) =>
      _user(uid).update({'onboardingGuideSeen': true});

  @override
  Future<void> signOut() async {
    await _initGoogle();
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    await _functions.httpsCallable('deleteAccount').call<void>();
    await signOut();
  }
}

/// 데모 모드: 네트워크 없이 고정 uid로 로그인한다.
/// 프로필은 데모 저장소(메모리)에 있으므로 여기서는 저장하지 않는다.
class DemoAccountRepository implements AccountRepository {
  const DemoAccountRepository();

  static const uid = 'me';

  @override
  Future<String?> restoreUid() async => null;

  @override
  Future<String?> signIn() async {
    // 로그인 창이 뜨는 시간처럼 아주 잠깐 기다린다.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return uid;
  }

  @override
  Future<AppUser?> loadProfile(String uid) async => null;

  @override
  Future<bool> isNicknameTaken(String uid, String nickname) async => false;

  @override
  Future<void> createProfile(AppUser user) async {}

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
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// 지금 쓰는 계정 저장소. Firebase가 준비되면 main.dart에서
/// [FirebaseAccountRepository]로 바꿔 끼운다.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => const DemoAccountRepository(),
);
