/// 기획 문서(전략·사용자 스토리·IA)에 정의된 수치 규칙.
/// 숫자를 화면 코드에 직접 쓰지 말고 여기서 가져다 쓴다.
abstract final class AppLimits {
  // US-002 닉네임
  static const nicknameMin = 2;
  static const nicknameMax = 10;

  // US-005 주제 한 줄
  static const topicMaxLength = 30;

  // US-007 대화 신청 한 마디
  static const requestMessageMin = 1;
  static const requestMessageMax = 40;

  /// US-007 신청 무응답 자동 만료
  static const requestExpiry = Duration(minutes: 30);

  /// US-009 / US-012 대화 보관 기간
  static const chatRetention = Duration(days: 7);

  /// 방에 입장할 수 있는 장소 반경(m). 이 안에 있는 사람끼리만 대화한다.
  static const roomRadiusMeters = 200.0;

  /// 방 이름 길이
  static const roomNameMin = 2;
  static const roomNameMax = 20;

  /// 주변 방 목록에 "범위 밖"으로 함께 보여줄 거리(m)
  static const nearbyListMeters = 1000.0;

  // US-004 입장 PIN(방 개설자가 만든다)
  static const spotCodeLength = 4;
  static const spotCodeMaxAttempts = 5;
  static const spotCodeLockDuration = Duration(minutes: 10);

  /// US-010 서로 다른 신고자 수 누적 시 이용 정지
  static const reportsUntilSuspension = 3;

  /// US-016 최근 주제 보관 개수
  static const recentTopicsCount = 3;

  /// US-014 카테고리별 예시 주제 개수
  static const topicExamplesPerCategory = 5;

  /// US-017 신뢰 표시가 붙는 "좋았어요" 수
  static const trustBadgeThreshold = 5;

  /// 최소 연령 (US-003)
  static const minimumAge = 19;

  // US-019 무료 / BIND+ 한도
  static const freeActiveTopics = 1;
  static const plusActiveTopics = 3;
  static const freeDailyRequests = 5;

  /// BIND+ 월 구독료(원)·구독 기간 (전략 문서 5장 가격 가설)
  static const plusMonthlyPriceWon = 4900;
  static const plusPeriod = Duration(days: 30);

  /// NSM: 양쪽이 각각 이 수 이상 메시지를 보내면 "성사 대화"
  static const successfulChatMinMessagesEach = 3;
}
