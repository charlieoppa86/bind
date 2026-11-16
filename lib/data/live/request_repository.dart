import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../place/place_search.dart';

/// 서버가 판단한 요청 보내기 결과
enum RemoteSendResult { sent, duplicate, dailyLimit, notCheckedIn, gone }

/// 대화 요청(`chatRequests`)·채팅방(`chats`)·상대 프로필(`users`) Firestore 저장소.
///
/// 요청 만들기·수락·거절은 신뢰가 필요해서 Cloud Functions만 한다
/// (하루 횟수, 중복, 만료, 채팅방 생성). 앱은 읽기 스트림만 연다.
class RequestRepository {
  RequestRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: FunctionsPlaceSearch.region);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<ChatRequest>> watchReceived(String uid) => _db
      .collection('chatRequests')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map(_toRequests);

  Stream<List<ChatRequest>> watchSent(String uid) => _db
      .collection('chatRequests')
      .where('fromUid', isEqualTo: uid)
      .snapshots()
      .map(_toRequests);

  /// 내가 들어 있는 채팅방 + 방마다 내 안 읽은 수
  Stream<List<(Chat, int)>> watchChats(String uid) => _db
      .collection('chats')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            (
              Chat.fromMap(d.id, d.data()),
              ((d.data()['unread'] as Map?)?[uid] as num?)?.toInt() ?? 0,
            ),
        ],
      );

  /// 대화방의 최근 메시지(보관 기간 7일이라 최근 300개면 충분하다)
  Stream<List<ChatMessage>> watchMessages(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(300)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs.reversed) ChatMessage.fromMap(d.id, d.data()),
        ],
      );

  /// 메시지 보내기. 마지막 메시지·안 읽은 수는 서버(onMessageCreated)가 갱신한다.
  /// [expiresAt]은 대화방과 같은 값(TTL로 함께 지워지도록).
  Future<void> sendMessage({
    required String chatId,
    required String uid,
    required String text,
    required DateTime expiresAt,
  }) => _db.collection('chats').doc(chatId).collection('messages').add({
    'senderUid': uid,
    'text': text,
    'sentAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(expiresAt),
  });

  /// 내 안 읽은 수를 0으로
  Future<void> markRead(String chatId, String uid) =>
      _db.collection('chats').doc(chatId).update({'unread.$uid': 0});

  Future<List<AppUser>> fetchUsers(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    final out = <AppUser>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      out.addAll([for (final d in snap.docs) AppUser.fromMap(d.id, d.data())]);
    }
    return out;
  }

  Future<RemoteSendResult> send({
    required String toCheckinId,
    required String message,
  }) async {
    final res = await _functions
        .httpsCallable('sendRequest')
        .call<Map<String, dynamic>>({
          'toCheckinId': toCheckinId,
          'message': message,
        });
    final name = res.data['result'] as String?;
    return RemoteSendResult.values.firstWhere(
      (r) => r.name == name,
      orElse: () => RemoteSendResult.gone,
    );
  }

  /// 수락하면 만들어진 채팅방 id, 거절·만료면 null
  Future<String?> respond(String requestId, {required bool accept}) async {
    final res = await _functions
        .httpsCallable('respondRequest')
        .call<Map<String, dynamic>>({'requestId': requestId, 'accept': accept});
    return res.data['chatId'] as String?;
  }

  static List<ChatRequest> _toRequests(QuerySnapshot<Map<String, dynamic>> s) =>
      [for (final d in s.docs) ChatRequest.fromMap(d.id, d.data())];
}
