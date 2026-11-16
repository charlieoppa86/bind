import '../../core/constants/enums.dart';
import 'firestore_utils.dart';

/// `chatRequests/{requestId}` (US-007, US-008)
///
/// 수락 전에는 채팅방이 존재하지 않는다. 수락 시 Cloud Functions가
/// `chats/{chatId}`를 만들고 [chatId]를 채운다.
class ChatRequest {
  const ChatRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.spotId,
    required this.toCheckinId,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.fromNickname = '',
    this.fromJobTag = JobTag.other,
    this.fromJobCustom,
    this.chatId,
  });

  factory ChatRequest.fromMap(String id, Map<String, dynamic> map) =>
      ChatRequest(
        id: id,
        fromUid: map['fromUid'] as String,
        toUid: map['toUid'] as String,
        spotId: map['spotId'] as String? ?? '',
        toCheckinId: map['toCheckinId'] as String? ?? '',
        message: map['message'] as String? ?? '',
        status: enumByName(
          ChatRequestStatus.values,
          map['status'],
          ChatRequestStatus.pending,
        ),
        createdAt: toDateTime(map['createdAt']) ?? DateTime.now(),
        expiresAt: toDateTime(map['expiresAt']) ?? DateTime.now(),
        fromNickname: map['fromNickname'] as String? ?? '',
        fromJobTag: enumByName(JobTag.values, map['fromJobTag'], JobTag.other),
        fromJobCustom: map['fromJobCustom'] as String?,
        chatId: map['chatId'] as String?,
      );

  final String id;
  final String fromUid;
  final String toUid;
  final String spotId;
  final String toCheckinId;

  /// 한 마디 1~40자
  final String message;
  final ChatRequestStatus status;
  final DateTime createdAt;

  /// createdAt + 30분
  final DateTime expiresAt;
  final String fromNickname;
  final JobTag fromJobTag;
  final String? fromJobCustom;

  /// 화면에 보이는 요청자의 하는 일. 기타를 고르고 직접 입력했으면 그 글자.
  String get fromJobLabel => jobLabelOf(fromJobTag, fromJobCustom);
  final String? chatId;

  ChatRequest copyWith({ChatRequestStatus? status, String? chatId}) =>
      ChatRequest(
        id: id,
        fromUid: fromUid,
        toUid: toUid,
        spotId: spotId,
        toCheckinId: toCheckinId,
        message: message,
        status: status ?? this.status,
        createdAt: createdAt,
        expiresAt: expiresAt,
        fromNickname: fromNickname,
        fromJobTag: fromJobTag,
        fromJobCustom: fromJobCustom,
        chatId: chatId ?? this.chatId,
      );
}
