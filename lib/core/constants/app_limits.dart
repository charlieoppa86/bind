/// 기획 문서(전략·사용자 스토리·IA)에 정의된 수치 규칙.
/// 숫자를 화면 코드에 직접 쓰지 말고 여기서 가져다 쓴다.
abstract final class AppLimits {
  // US-002 닉네임
  static const nicknameMin = 2;
  static const nicknameMax = 10;

  /// 하는 일을 기타로 고르고 직접 입력할 때 글자 수
  static const jobCustomMax = 10;

  // US-005 주제 한 줄
  static const topicMaxLength = 30;

  // US-007 대화 신청 한 마디
  static const requestMessageMin = 1;
  static const requestMessageMax = 40;

  /// US-007 신청 무응답 자동 만료
  static const requestExpiry = Duration(minutes: 30);

  /// US-009 / US-012 대화 보관 기간
  static const chatRetention = Duration(days: 7);

  /// 장소 이름 길이(자유 입력)
  static const placeNameMin = 2;
  static const placeNameMax = 20;

  /// 체크인 화면의 "최근 간 장소" 개수
  static const recentPlacesCount = 3;

  /// US-010 서로 다른 신고자 수 누적 시 이용 정지
  static const reportsUntilSuspension = 2;

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
