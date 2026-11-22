import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../place/place_search.dart';

/// 서버가 판단한 요청 보내기 결과
enum RemoteSendResult { sent, duplicate, dailyLimit, notCheckedIn, gone }

/// 서버가 판단한 그룹 채팅 참여 결과(joinGroupChat)
enum RemoteJoinResult { joined, full, notCheckedIn, gone }

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

  /// 대화방의 최근 메시지 300개
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
  Future<void> sendMessage({
    required String chatId,
    required String uid,
    required String text,
  }) => _db.collection('chats').doc(chatId).collection('messages').add({
    'senderUid': uid,
    'text': text,
    'sentAt': FieldValue.serverTimestamp(),
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

  /// 카드에 열린 그룹 채팅에 들어간다(US-025). 같은 장소·차단·인원은 서버가 확인한다.
  Future<(RemoteJoinResult, String?)> joinGroupChat(String checkinId) async {
    final res = await _functions
        .httpsCallable('joinGroupChat')
        .call<Map<String, dynamic>>({'checkinId': checkinId});
    final name = res.data['result'] as String?;
    final result = RemoteJoinResult.values.firstWhere(
      (r) => r.name == name,
      orElse: () => RemoteJoinResult.gone,
    );
    return (result, res.data['chatId'] as String?);
  }

  /// 그룹 채팅에서 나간다. 멤버 목록에서 빠지고 카드의 인원 수가 줄어든다.
  Future<void> leaveGroupChat(String chatId) => _functions
      .httpsCallable('leaveGroupChat')
      .call<Map<String, dynamic>>({'chatId': chatId});

  static List<ChatRequest> _toRequests(QuerySnapshot<Map<String, dynamic>> s) =>
      [for (final d in s.docs) ChatRequest.fromMap(d.id, d.data())];
}
