import '../../core/constants/enums.dart';
import 'firestore_utils.dart';

/// `chats/{chatId}` — 채팅방. 보관 기간 제한 없이 남는다(2026-11-23 결정, US-009, US-012).
///
/// - 1:1 채팅([ChatType.direct]): 대화 요청을 수락하면 Functions(respondRequest)가 만든다.
/// - 그룹 채팅([ChatType.group], US-025): 체크인할 때 "그룹 채팅도 열기"를 켜면
///   Functions(onCheckinWritten)가 만들고, 같은 장소 사람은 joinGroupChat으로 들어온다.
///
/// [messageCounts]는 NSM(1:1에서 양쪽 각 3개 이상) 집계용으로 Functions가 갱신한다.
class Chat {
  const Chat({
    required this.id,
    required this.memberUids,
    required this.createdAt,
    this.type = ChatType.direct,
    this.title,
    this.ownerUid,
    this.checkinId,
    this.lastMessage,
    this.lastMessageAt,
    this.messageCounts = const {},
    this.leftUids = const [],
  });

  factory Chat.fromMap(String id, Map<String, dynamic> map) => Chat(
    id: id,
    memberUids: List<String>.from(map['memberUids'] as List? ?? const []),
    createdAt: toDateTime(map['createdAt']) ?? DateTime.now(),
    type: enumByName(ChatType.values, map['type'], ChatType.direct),
    title: map['title'] as String?,
    ownerUid: map['ownerUid'] as String?,
    checkinId: map['checkinId'] as String?,
    lastMessage: map['lastMessage'] as String?,
    lastMessageAt: toDateTime(map['lastMessageAt']),
    messageCounts: Map<String, int>.from(
      map['messageCounts'] as Map? ?? const {},
    ),
    leftUids: List<String>.from(map['leftUids'] as List? ?? const []),
  );

  final String id;
  final List<String> memberUids;
  final DateTime createdAt;
  final ChatType type;

  /// 그룹 채팅 이름(연 사람의 주제 한 줄). 1:1은 null.
  final String? title;

  /// 그룹 채팅을 연 사람. 1:1은 null.
  final String? ownerUid;

  /// 그룹 채팅을 연 카드(`checkins/{id}`). 1:1은 null.
  final String? checkinId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> messageCounts;

  /// 탈퇴한 멤버 → "떠난 사용자" 표시(1:1은 입력창 비활성)
  final List<String> leftUids;

  bool get isGroup => type == ChatType.group;

  /// 지금 남아 있는 사람 수(탈퇴한 사람 제외)
  int get activeMemberCount =>
      memberUids.where((u) => !leftUids.contains(u)).length;

  Chat copyWith({
    List<String>? memberUids,
    String? title,
    String? lastMessage,
    DateTime? lastMessageAt,
    Map<String, int>? messageCounts,
    List<String>? leftUids,
  }) => Chat(
    id: id,
    memberUids: memberUids ?? this.memberUids,
    createdAt: createdAt,
    type: type,
    title: title ?? this.title,
    ownerUid: ownerUid,
    checkinId: checkinId,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    messageCounts: messageCounts ?? this.messageCounts,
    leftUids: leftUids ?? this.leftUids,
  );

  /// 1:1 채팅의 상대. 그룹 채팅에서는 쓰지 않는다.
  String otherUid(String myUid) =>
      memberUids.firstWhere((u) => u != myUid, orElse: () => '');
}

/// 메시지 종류. 이름(name)은 Firestore `kind`에 저장되므로 바꾸지 않는다.
enum MessageKind {
  /// 이용자가 보낸 글
  text,

  /// 그룹 채팅 안내 "○○님이 입장했습니다"(서버가 쓴다)
  join,

  /// 그룹 채팅 안내 "○○님이 나갔습니다"(서버가 쓴다)
  leave;

  bool get isNotice => this != text;
}

/// `chats/{chatId}/messages/{messageId}` — 텍스트만(US-W04, 사진 전송 없음).
///
/// 그룹 채팅의 입장·퇴장 안내도 같은 컬렉션에 [MessageKind.join]/[MessageKind.leave]로
/// 들어간다. 안내의 [senderUid]는 들어오거나 나간 사람, [text]는 화면에 보일 문장이다
/// (그 사람이 탈퇴하면 안내도 함께 지워진다).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.sentAt,
    this.kind = MessageKind.text,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        senderUid: map['senderUid'] as String? ?? '',
        text: map['text'] as String? ?? '',
        sentAt: toDateTime(map['sentAt']) ?? DateTime.now(),
        kind: enumByName(MessageKind.values, map['kind'], MessageKind.text),
      );

  final String id;
  final String senderUid;
  final String text;
  final DateTime sentAt;
  final MessageKind kind;

  /// "○○님이 입장했습니다" / "○○님이 나갔습니다"
  static String noticeText(MessageKind kind, String nickname) => switch (kind) {
    MessageKind.join => '$nickname님이 입장했습니다',
    MessageKind.leave => '$nickname님이 나갔습니다',
    MessageKind.text => '',
  };

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    'text': text,
    'sentAt': toTimestamp(sentAt),
  };
}
