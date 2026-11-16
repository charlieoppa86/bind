import '../../core/constants/enums.dart';
import 'firestore_utils.dart';

/// `checkins/{checkinId}` — 스팟 피드에 노출되는 "주제 카드".
///
/// 카드에는 닉네임·직무·주제만 보인다(US-006).
/// 피드 조회 시 닉네임/직무를 매번 조인하지 않도록 비정규화해 둔다.
class Checkin {
  const Checkin({
    required this.id,
    required this.uid,
    required this.spotId,
    required this.nickname,
    required this.jobTag,
    this.jobCustom,
    required this.topic,
    required this.category,
    required this.startedAt,
    this.checkedOutAt,
    this.hasTrustBadge = false,
    this.notifyWhenSomeoneArrives = false,
  });

  factory Checkin.fromMap(String id, Map<String, dynamic> map) => Checkin(
    id: id,
    uid: map['uid'] as String? ?? '',
    spotId: map['spotId'] as String? ?? '',
    nickname: map['nickname'] as String? ?? '',
    jobTag: enumByName(JobTag.values, map['jobTag'], JobTag.other),
    jobCustom: map['jobCustom'] as String?,
    topic: map['topic'] as String? ?? '',
    category: enumByName(
      TopicCategory.values,
      map['category'],
      TopicCategory.other,
    ),
    startedAt: toDateTime(map['startedAt']) ?? DateTime.now(),
    checkedOutAt: toDateTime(map['checkedOutAt']),
    hasTrustBadge: map['hasTrustBadge'] as bool? ?? false,
    notifyWhenSomeoneArrives: map['notifyWhenSomeoneArrives'] as bool? ?? false,
  );

  final String id;
  final String uid;
  final String spotId;
  final String nickname;
  final JobTag jobTag;
  final String? jobCustom;

  /// 화면에 보이는 하는 일. 기타를 고르고 직접 입력했으면 그 글자.
  String get jobLabel => jobLabelOf(jobTag, jobCustom);
  final String topic;
  final TopicCategory category;
  final DateTime startedAt;
  final DateTime? checkedOutAt;
  final bool hasTrustBadge;

  /// US-015 "누가 오면 알려줘"
  final bool notifyWhenSomeoneArrives;

  /// 체류 시간 제한이 없다. 체크아웃 전까지 보인다.
  bool isActiveAt(DateTime now) => checkedOutAt == null;

  /// 같은 카드를 다른 uid로(실제 모드에서 내 uid를 앱 안 별칭으로 바꿀 때)
  Checkin withUid(String uid) => Checkin(
    id: id,
    uid: uid,
    spotId: spotId,
    nickname: nickname,
    jobTag: jobTag,
    jobCustom: jobCustom,
    topic: topic,
    category: category,
    startedAt: startedAt,
    checkedOutAt: checkedOutAt,
    hasTrustBadge: hasTrustBadge,
    notifyWhenSomeoneArrives: notifyWhenSomeoneArrives,
  );

  Checkin copyWith({
    String? topic,
    TopicCategory? category,
    DateTime? checkedOutAt,
    bool? notifyWhenSomeoneArrives,
  }) => Checkin(
    id: id,
    uid: uid,
    spotId: spotId,
    nickname: nickname,
    jobTag: jobTag,
    jobCustom: jobCustom,
    topic: topic ?? this.topic,
    category: category ?? this.category,
    startedAt: startedAt,
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
    'jobCustom': jobCustom,
    'topic': topic,
    'category': category.name,
    'startedAt': toTimestamp(startedAt),
    'checkedOutAt': toTimestamp(checkedOutAt),
    'notifyWhenSomeoneArrives': notifyWhenSomeoneArrives,
  };
}
