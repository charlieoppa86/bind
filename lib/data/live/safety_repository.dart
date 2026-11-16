import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/enums.dart';
import '../models/app_user.dart';
import '../models/safety.dart';

/// 차단(`users/{uid}/blocks`)·신고(`reports`)·대화 평가(`chats/{id}/reviews`)와
/// 내 프로필 실시간 변경(정지·좋았어요 수) Firestore 저장소.
///
/// 정지와 "좋았어요" 수는 신뢰가 필요해서 Cloud Functions만 쓴다
/// (onReportCreated, onReviewCreated). 앱은 신고·평가 문서를 만들기만 한다.
class SafetyRepository {
  SafetyRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _blocks(String uid) =>
      _db.collection('users').doc(uid).collection('blocks');

  Stream<List<Block>> watchBlocks(String uid) =>
      _blocks(uid)
          .snapshots()
          .map((s) => [for (final d in s.docs) Block.fromMap(d.id, d.data())]);

  /// 내 프로필 변화(정지·좋았어요 수·BIND+). 온보딩 전이면 null.
  Stream<AppUser?> watchMe(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : AppUser.fromMap(s.id, data);
      });

  Future<void> block(String uid, String targetUid, String targetNickname) =>
      _blocks(uid).doc(targetUid).set({
        'targetNickname': targetNickname,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> unblock(String uid, String targetUid) =>
      _blocks(uid).doc(targetUid).delete();

  /// 한 사람이 같은 사람을 여러 번 신고해도 1건(문서 id = 신고자_대상).
  Future<void> report({
    required String uid,
    required String targetUid,
    required ReportReason reason,
    required ReportSource source,
    required bool alsoBlocked,
  }) => _db.collection('reports').doc('${uid}_$targetUid').set({
    'reporterUid': uid,
    'targetUid': targetUid,
    'reason': reason.name,
    'source': source.name,
    'alsoBlocked': alsoBlocked,
    'createdAt': FieldValue.serverTimestamp(),
  });

  /// 대화 평가(대화방마다 한 번, 평가자는 비공개)
  Future<void> review({
    required String uid,
    required String chatId,
    required String targetUid,
    required ChatReviewRating rating,
  }) => _db.collection('chats').doc(chatId).collection('reviews').doc(uid).set({
    'targetUid': targetUid,
    'rating': rating.name,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
