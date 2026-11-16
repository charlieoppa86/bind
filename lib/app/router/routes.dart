/// docs/BIND_IA.md "Flutter 라우트 매핑" 표의 경로.
/// 화면 이동은 문자열을 직접 쓰지 말고 이 클래스를 사용한다.
abstract final class Routes {
  // 인증
  static const splash = '/splash';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingConsent = '/onboarding/consent';
  static const onboardingGuide = '/onboarding/guide';

  // 체크인
  static const checkin = '/checkin';
  static const checkinSpots = '/checkin/spots';

  static const checkinTopic = '/checkin/topic';
  static const checkinTopicExamples = '/checkin/topic/examples';

  /// 주제 수정([editId]) / 주제 추가([add])
  static String topicSetup({String? editId, bool add = false}) => Uri(
    path: checkinTopic,
    queryParameters: {'edit': ?editId, if (add) 'add': '1'},
  ).toString();

  static String topicExamples(String category) =>
      '$checkinTopicExamples?category=$category';

  // 탭 1: 스팟
  static const spot = '/spot';
  static String spotRequest(String userId) => '/spot/request/$userId';
  static const spotMe = '/spot/me';

  // 탭 2: 신청함
  static const requests = '/requests';
  static const requestsReceived = '/requests/received';
  static String requestDetail(String requestId) =>
      '/requests/received/$requestId';
  static const requestsSent = '/requests/sent';

  // 탭 3: 채팅
  static const chats = '/chats';
  static String chatRoom(String chatId) => '/chats/$chatId';
  static String chatReview(String chatId) => '/chats/$chatId/review';

  // 탭 4: 마이
  static const my = '/my';
  static const myProfile = '/my/profile';
  static const myPlus = '/my/plus';
  static const myBlocked = '/my/blocked';
  static const myConsent = '/my/consent';
  static const myGuide = '/my/guide';
  static const myAccount = '/my/account';

  // 글로벌
  static String report(String targetId, {String? source}) =>
      '/report/$targetId${source == null ? '' : '?source=$source'}';
  static String block(String targetId) => '/block/$targetId';
  static const suspended = '/suspended';
}
