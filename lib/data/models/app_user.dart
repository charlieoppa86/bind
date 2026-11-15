import '../../core/constants/enums.dart';
import '../../core/constants/app_limits.dart';
import 'firestore_utils.dart';

/// `users/{uid}`
///
/// 실명·사진은 저장하지 않는다(US-002, US-W05).
class AppUser {
  const AppUser({
    required this.uid,
    required this.nickname,
    required this.jobTag,
    required this.consentedAt,
    this.goodReviewCount = 0,
    this.isPlus = false,
    this.plusExpiresAt,
    this.suspended = false,
    this.deleted = false,
    this.onboardingGuideSeen = false,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    nickname: map['nickname'] as String? ?? '',
    jobTag: enumByName(JobTag.values, map['jobTag'], JobTag.other),
    consentedAt: toDateTime(map['consentedAt']),
    goodReviewCount: map['goodReviewCount'] as int? ?? 0,
    isPlus: map['isPlus'] as bool? ?? false,
    plusExpiresAt: toDateTime(map['plusExpiresAt']),
    suspended: map['suspended'] as bool? ?? false,
    deleted: map['deleted'] as bool? ?? false,
    onboardingGuideSeen: map['onboardingGuideSeen'] as bool? ?? false,
  );

  final String uid;
  final String nickname;
  final JobTag jobTag;

  /// 만 19세 이상 확인 + 이용 규칙 3줄 동의 시각(US-003). null이면 온보딩 미완료.
  final DateTime? consentedAt;

  /// "좋았어요" 받은 수(US-017). Cloud Functions만 갱신.
  final int goodReviewCount;
  final bool isPlus;
  final DateTime? plusExpiresAt;

  /// 서로 다른 3명에게 신고되면 true(US-010). Cloud Functions만 갱신.
  final bool suspended;

  /// 탈퇴 사용자 → 상대에게 "떠난 사용자"로 표시(US-012).
  final bool deleted;
  final bool onboardingGuideSeen;

  bool get hasTrustBadge => goodReviewCount >= AppLimits.trustBadgeThreshold;
  bool get isOnboarded => nickname.isNotEmpty && consentedAt != null;

  AppUser copyWith({
    String? nickname,
    JobTag? jobTag,
    DateTime? consentedAt,
    int? goodReviewCount,
    bool? isPlus,
    DateTime? Function()? plusExpiresAt,
    bool? suspended,
    bool? deleted,
    bool? onboardingGuideSeen,
  }) => AppUser(
    uid: uid,
    nickname: nickname ?? this.nickname,
    jobTag: jobTag ?? this.jobTag,
    consentedAt: consentedAt ?? this.consentedAt,
    goodReviewCount: goodReviewCount ?? this.goodReviewCount,
    isPlus: isPlus ?? this.isPlus,
    plusExpiresAt: plusExpiresAt != null ? plusExpiresAt() : this.plusExpiresAt,
    suspended: suspended ?? this.suspended,
    deleted: deleted ?? this.deleted,
    onboardingGuideSeen: onboardingGuideSeen ?? this.onboardingGuideSeen,
  );

  Map<String, dynamic> toMap() => {
    'nickname': nickname,
    'jobTag': jobTag.name,
    'consentedAt': toTimestamp(consentedAt),
    'onboardingGuideSeen': onboardingGuideSeen,
  };
}
