import '../../core/constants/enums.dart';
import 'firestore_utils.dart';

/// `reports/{reportId}` — 클라이언트는 생성만, 읽기 불가.
/// Functions가 서로 다른 신고자 3명 누적 시 대상 계정을 정지한다.
class Report {
  const Report({
    required this.reporterUid,
    required this.targetUid,
    required this.reason,
    required this.source,
    required this.createdAt,
    this.alsoBlocked = false,
  });

  final String reporterUid;
  final String targetUid;
  final ReportReason reason;
  final ReportSource source;
  final DateTime createdAt;
  final bool alsoBlocked;

  Map<String, dynamic> toMap() => {
    'reporterUid': reporterUid,
    'targetUid': targetUid,
    'reason': reason.name,
    'source': source.name,
    'alsoBlocked': alsoBlocked,
    'createdAt': toTimestamp(createdAt),
  };
}

/// `users/{uid}/blocks/{targetUid}` — 차단한 사람의 카드·신청은 비노출(US-010).
class Block {
  const Block({
    required this.targetUid,
    required this.targetNickname,
    required this.createdAt,
  });

  factory Block.fromMap(String targetUid, Map<String, dynamic> map) => Block(
    targetUid: targetUid,
    targetNickname: map['targetNickname'] as String? ?? '',
    createdAt: toDateTime(map['createdAt']) ?? DateTime.now(),
  );

  final String targetUid;
  final String targetNickname;
  final DateTime createdAt;
}

/// `chats/{chatId}/reviews/{reviewerUid}` — 평가자는 서로 비공개(US-017).
class ChatReview {
  const ChatReview({
    required this.reviewerUid,
    required this.targetUid,
    required this.rating,
  });

  final String reviewerUid;
  final String targetUid;
  final ChatReviewRating rating;

  Map<String, dynamic> toMap() => {
    'targetUid': targetUid,
    'rating': rating.name,
  };
}
