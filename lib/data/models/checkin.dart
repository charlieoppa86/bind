import '../../core/constants/enums.dart';
import 'firestore_utils.dart';

/// `checkins/{checkinId}` — 스팟 피드에 노출되는 "주제 카드".
///
/// 카드에는 닉네임·직무·주제·남은 시간만 보인다(US-006).
/// 피드 조회 시 닉네임/직무를 매번 조인하지 않도록 비정규화해 둔다.
class Checkin {
  const Checkin({
    required this.id,
    required this.uid,
    required this.spotId,
    required this.nickname,
    required this.jobTag,
    required this.topic,
    required this.category,
    required this.startedAt,
    required this.endsAt,
    this.checkedOutAt,
    this.hasTrustBadge = false,
    this.notifyWhenSomeoneArrives = false,
  });

  factory Checkin.fromMap(String id, Map<String, dynamic> map) => Checkin(
    id: id,
    uid: map['uid'] as String,
    spotId: map['spotId'] as String,
    nickname: map['nickname'] as String? ?? '',
    jobTag: enumByName(JobTag.values, map['jobTag'], JobTag.other),
    topic: map['topic'] as String? ?? '',
    category: enumByName(
      TopicCategory.values,
      map['category'],
      TopicCategory.other,
    ),
    startedAt: toDateTime(map['startedAt']) ?? DateTime.now(),
    endsAt: toDateTime(map['endsAt']) ?? DateTime.now(),
    checkedOutAt: toDateTime(map['checkedOutAt']),
    hasTrustBadge: map['hasTrustBadge'] as bool? ?? false,
    notifyWhenSomeoneArrives: map['notifyWhenSomeoneArrives'] as bool? ?? false,
  );

  final String id;
  final String uid;
  final String spotId;
  final String nickname;
  final JobTag jobTag;
  final String topic;
  final TopicCategory category;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? checkedOutAt;
  final bool hasTrustBadge;

  /// US-015 "누가 오면 알려줘"
  final bool notifyWhenSomeoneArrives;

  bool isActiveAt(DateTime now) => checkedOutAt == null && now.isBefore(endsAt);

  Duration remaining(DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  Checkin copyWith({
    String? topic,
    TopicCategory? category,
    DateTime? endsAt,
    DateTime? checkedOutAt,
    bool? notifyWhenSomeoneArrives,
  }) => Checkin(
    id: id,
    uid: uid,
    spotId: spotId,
    nickname: nickname,
    jobTag: jobTag,
    topic: topic ?? this.topic,
    category: category ?? this.category,
    startedAt: startedAt,
    endsAt: endsAt ?? this.endsAt,
    checkedOutAt: checkedOutAt ?? this.checkedOutAt,
    hasTrustBadge: hasTrustBadge,
    notifyWhenSomeoneArrives:
        notifyWhenSomeoneArrives ?? this.notifyWhenSomeoneArrives,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'spotId': spotId,
    'nickname': nickname,
    'jobTag': jobTag.name,
    'topic': topic,
    'category': category.name,
    'startedAt': toTimestamp(startedAt),
    'endsAt': toTimestamp(endsAt),
    'checkedOutAt': toTimestamp(checkedOutAt),
    'notifyWhenSomeoneArrives': notifyWhenSomeoneArrives,
  };
}
