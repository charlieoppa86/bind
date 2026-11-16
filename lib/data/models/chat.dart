import 'firestore_utils.dart';

/// `chats/{chatId}` — 1:1 채팅방. 7일 후 자동 삭제(US-009, US-012).
///
/// [messageCounts]는 NSM(양쪽 각 3개 이상) 집계용으로 Functions가 갱신한다.
class Chat {
  const Chat({
    required this.id,
    required this.memberUids,
    required this.createdAt,
    required this.expiresAt,
    this.lastMessage,
    this.lastMessageAt,
    this.messageCounts = const {},
    this.leftUids = const [],
  });

  factory Chat.fromMap(String id, Map<String, dynamic> map) => Chat(
    id: id,
    memberUids: List<String>.from(map['memberUids'] as List? ?? const []),
    createdAt: toDateTime(map['createdAt']) ?? DateTime.now(),
    expiresAt: toDateTime(map['expiresAt']) ?? DateTime.now(),
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

  /// createdAt + 7일. Firestore TTL 정책 대상 필드.
  final DateTime expiresAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> messageCounts;

  /// 탈퇴한 멤버 → "떠난 사용자" 표시, 입력창 비활성
  final List<String> leftUids;

  Chat copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    Map<String, int>? messageCounts,
    List<String>? leftUids,
  }) => Chat(
    id: id,
    memberUids: memberUids,
    createdAt: createdAt,
    expiresAt: expiresAt,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    messageCounts: messageCounts ?? this.messageCounts,
    leftUids: leftUids ?? this.leftUids,
  );

  String otherUid(String myUid) =>
      memberUids.firstWhere((u) => u != myUid, orElse: () => '');
}

/// `chats/{chatId}/messages/{messageId}` — 텍스트만(US-W04).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        senderUid: map['senderUid'] as String? ?? '',
        text: map['text'] as String? ?? '',
        sentAt: toDateTime(map['sentAt']) ?? DateTime.now(),
      );

  final String id;
  final String senderUid;
  final String text;
  final DateTime sentAt;

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    'text': text,
    'sentAt': toTimestamp(sentAt),
  };
}
