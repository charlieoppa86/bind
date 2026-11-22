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
    this.categoryCustom,
    required this.startedAt,
    this.checkedOutAt,
    this.hasTrustBadge = false,
    this.notifyWhenSomeoneArrives = false,
    this.openGroupChat = false,
    this.groupChatId,
    this.groupMemberCount = 0,
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
    categoryCustom: map['categoryCustom'] as String?,
    startedAt: toDateTime(map['startedAt']) ?? DateTime.now(),
    checkedOutAt: toDateTime(map['checkedOutAt']),
    hasTrustBadge: map['hasTrustBadge'] as bool? ?? false,
    notifyWhenSomeoneArrives: map['notifyWhenSomeoneArrives'] as bool? ?? false,
    openGroupChat: map['openGroupChat'] as bool? ?? false,
    groupChatId: map['groupChatId'] as String?,
    groupMemberCount: (map['groupMemberCount'] as num?)?.toInt() ?? 0,
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

  /// 키워드로 "기타"를 고르고 직접 입력한 글자
  final String? categoryCustom;

  /// 카드에 보이는 키워드. 기타를 고르고 직접 입력했으면 그 글자.
  String get keywordLabel => keywordLabelOf(category, categoryCustom);
  final DateTime startedAt;
  final DateTime? checkedOutAt;
  final bool hasTrustBadge;

  /// US-015 "누가 오면 알려줘"
  final bool notifyWhenSomeoneArrives;

  /// US-025 체크인할 때 "그룹 채팅도 열기"를 켰는지(앱이 쓰는 값).
  /// 서버(onCheckinWritten)가 이 값을 보고 그룹 채팅방을 만든다.
  final bool openGroupChat;

  /// 이 카드로 연 그룹 채팅방 id. 서버만 쓴다. 없으면 1:1 요청만 받는다.
  final String? groupChatId;

  /// 그룹 채팅에 지금 있는 사람 수. 방에 들어가지 않은 사람도 카드에서 보도록
  /// 서버가 카드에 적어 둔다(방 문서는 참여자만 읽을 수 있다).
  final int groupMemberCount;

  bool get hasGroupChat => groupChatId != null;

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
    categoryCustom: categoryCustom,
    startedAt: startedAt,
    checkedOutAt: checkedOutAt,
    hasTrustBadge: hasTrustBadge,
    notifyWhenSomeoneArrives: notifyWhenSomeoneArrives,
    openGroupChat: openGroupChat,
    groupChatId: groupChatId,
    groupMemberCount: groupMemberCount,
  );

  Checkin copyWith({
    String? topic,
    TopicCategory? category,
    String? Function()? categoryCustom,
    DateTime? checkedOutAt,
    bool? notifyWhenSomeoneArrives,
    String? groupChatId,
    int? groupMemberCount,
  }) => Checkin(
    id: id,
    uid: uid,
    spotId: spotId,
    nickname: nickname,
    jobTag: jobTag,
    jobCustom: jobCustom,
    topic: topic ?? this.topic,
    category: category ?? this.category,
    categoryCustom: categoryCustom != null
        ? categoryCustom()
        : this.categoryCustom,
    startedAt: startedAt,
    checkedOutAt: checkedOutAt ?? this.checkedOutAt,
    hasTrustBadge: hasTrustBadge,
    notifyWhenSomeoneArrives:
        notifyWhenSomeoneArrives ?? this.notifyWhenSomeoneArrives,
    openGroupChat: openGroupChat,
    groupChatId: groupChatId ?? this.groupChatId,
    groupMemberCount: groupMemberCount ?? this.groupMemberCount,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'spotId': spotId,
    'nickname': nickname,
    'jobTag': jobTag.name,
    'jobCustom': jobCustom,
    'topic': topic,
    'category': category.name,
    'categoryCustom': categoryCustom,
    'startedAt': toTimestamp(startedAt),
    'checkedOutAt': toTimestamp(checkedOutAt),
    'notifyWhenSomeoneArrives': notifyWhenSomeoneArrives,
    'openGroupChat': openGroupChat,
  };
}
