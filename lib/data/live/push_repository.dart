import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../place/place_search.dart';

/// 푸시 토큰(`users/{uid}/fcmTokens/{token}`)과 구독 토픽(`users/{uid}.pushTopics`) 저장소.
///
/// 서버(Cloud Functions)는 이 토큰들로 사람별 알림을 보내고, 만료된 토큰은 스스로 지운다.
class PushRepository {
  PushRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _db = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: FunctionsPlaceSearch.region);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> saveToken(String uid, String token, String platform) =>
      _user(uid).collection('fcmTokens').doc(token).set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteToken(String uid, String token) =>
      _user(uid).collection('fcmTokens').doc(token).delete();

  /// 저장해 둔 구독 토픽(없으면 null → 기본값을 쓴다)
  Future<Set<String>?> loadTopics(String uid) async {
    final list = (await _user(uid).get()).data()?['pushTopics'] as List?;
    return list?.whereType<String>().toSet();
  }

  Future<void> saveTopics(String uid, Set<String> topics) =>
      _user(uid).update({'pushTopics': topics.toList()..sort()});

  /// 개발용: 내 기기로 테스트 알림 보내기(token: 내 토큰들 / topic: 내 개인 토픽)
  /// [delaySeconds] 뒤에 보낸다(그사이 앱을 백그라운드로 보내거나 종료해 시험).
  Future<void> sendTest({required bool viaTopic, int delaySeconds = 0}) =>
      _functions.httpsCallable('sendTestPush').call<void>({
        'mode': viaTopic ? 'topic' : 'token',
        'delaySeconds': delaySeconds,
      });
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(),
);
