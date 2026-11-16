import '../../core/constants/app_limits.dart';
import '../../core/constants/enums.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../models/checkin.dart';
import '../models/spot.dart';

/// 데모 모드 더미 데이터. Firebase 연결 전 화면 흐름을 실제처럼 확인하기 위한 값이다.
/// 스팟·사람·대화는 모두 가상이다.
abstract final class DemoSeed {
  static const myUid = 'me';

  /// 사용자들이 입력해 둔 장소. 같은 장소를 입력하면 이 카드들이 보인다.
  static const spots = <Spot>[
    Spot(id: 'seongsu', name: '성수 워크라운지', creatorUid: 'u-yuna'),
    Spot(id: 'seongsu-popup', name: '연무장길 팝업 스토어', creatorUid: 'u-minseo'),
    Spot(id: 'pangyo-conf', name: '판교 프로덕트 컨퍼런스', creatorUid: 'u-kang'),
    Spot(id: 'yeonnam', name: '연남 코워킹 하우스', creatorUid: 'u-eunbi'),
    Spot(id: 'sinchon-lib', name: '신촌 중앙도서관', creatorUid: 'u-nari'),
  ];

  static const users = <AppUser>[
    AppUser(
      uid: 'u-doyun',
      nickname: '도윤',
      jobTag: JobTag.developer,
      consentedAt: null,
      goodReviewCount: 7,
    ),
    AppUser(
      uid: 'u-harin',
      nickname: '하린',
      jobTag: JobTag.marketer,
      consentedAt: null,
      goodReviewCount: 3,
    ),
    AppUser(
      uid: 'u-minseo',
      nickname: '민서디자인',
      jobTag: JobTag.designer,
      consentedAt: null,
      goodReviewCount: 5,
    ),
    AppUser(
      uid: 'u-jaehyun',
      nickname: '재현',
      jobTag: JobTag.founder,
      consentedAt: null,
      goodReviewCount: 1,
    ),
    AppUser(
      uid: 'u-sora',
      nickname: '소라',
      jobTag: JobTag.developer,
      consentedAt: null,
    ),
    AppUser(
      uid: 'u-taeo',
      nickname: '태오',
      jobTag: JobTag.other,
      consentedAt: null,
      goodReviewCount: 2,
    ),
    AppUser(
      uid: 'u-yuna',
      nickname: '유나PM',
      jobTag: JobTag.other,
      consentedAt: null,
      goodReviewCount: 9,
    ),
    AppUser(
      uid: 'u-gunwoo',
      nickname: '건우',
      jobTag: JobTag.student,
      consentedAt: null,
    ),
    AppUser(
      uid: 'u-jiwon',
      nickname: '지원',
      jobTag: JobTag.marketer,
      consentedAt: null,
      goodReviewCount: 6,
    ),
    AppUser(
      uid: 'u-seojun',
      nickname: '서준',
      jobTag: JobTag.developer,
      consentedAt: null,
      goodReviewCount: 4,
    ),
    AppUser(
      uid: 'u-eunbi',
      nickname: '은비',
      jobTag: JobTag.designer,
      consentedAt: null,
    ),
    AppUser(
      uid: 'u-hyunsoo',
      nickname: '현수',
      jobTag: JobTag.founder,
      consentedAt: null,
      goodReviewCount: 5,
    ),
    AppUser(
      uid: 'u-nari',
      nickname: '나리',
      jobTag: JobTag.student,
      consentedAt: null,
      goodReviewCount: 1,
    ),
    AppUser(
      uid: 'u-kang',
      nickname: '강코치',
      jobTag: JobTag.other,
      consentedAt: null,
    ),
    AppUser(
      uid: 'u-hana',
      nickname: '하나',
      jobTag: JobTag.designer,
      consentedAt: null,
      goodReviewCount: 2,
    ),
    AppUser(
      uid: 'u-junho',
      nickname: '준호',
      jobTag: JobTag.student,
      consentedAt: null,
    ),
    AppUser(
      uid: 'u-left',
      nickname: '시우',
      jobTag: JobTag.developer,
      consentedAt: null,
      deleted: true,
    ),
  ];

  /// (uid, spotId, 주제, 카테고리, 체크인 후 지난 분, 예비)
  static const _cards = <(String, String, String, TopicCategory, int, int)>[
    (
      'u-doyun',
      'seongsu',
      'Riverpod 3 마이그레이션 해보신 분?',
      TopicCategory.dev,
      40,
      140,
    ),
    ('u-harin', 'seongsu', '1인 마케터 예산 배분 고민', TopicCategory.marketing, 25, 95),
    (
      'u-minseo',
      'seongsu',
      '디자인 시스템 처음 만드는 중이에요',
      TopicCategory.design,
      70,
      50,
    ),
    ('u-jaehyun', 'seongsu', 'MVP 검증 어떻게 하셨어요', TopicCategory.startup, 10, 170),
    ('u-sora', 'seongsu', '프리랜서 첫 계약서 같이 봐주실 분', TopicCategory.career, 90, 30),
    ('u-taeo', 'seongsu', '성수 점심 맛집 공유해요', TopicCategory.culture, 15, 45),
    ('u-yuna', 'seongsu', 'PM 커리어 피벗 얘기 나눠요', TopicCategory.career, 5, 115),
    ('u-hana', 'seongsu', '사이드 프로젝트 같이 고민해요', TopicCategory.dev, 20, 100),
    ('u-junho', 'seongsu', '요즘 읽는 책 얘기해요', TopicCategory.culture, 35, 85),
    (
      'u-minseo',
      'seongsu-popup',
      '팝업 브랜딩 어떻게 보세요?',
      TopicCategory.design,
      15,
      75,
    ),
    ('u-yuna', 'pangyo-conf', '오전 세션 정리 같이 해요', TopicCategory.study, 30, 90),
    (
      'u-jiwon',
      'pangyo-conf',
      '퍼포먼스 광고 요즘 효율 어때요',
      TopicCategory.marketing,
      20,
      160,
    ),
    (
      'u-seojun',
      'pangyo-conf',
      'AI 코딩 도구 실무에서 어떻게 써요?',
      TopicCategory.dev,
      45,
      75,
    ),
    (
      'u-hyunsoo',
      'pangyo-conf',
      '첫 투자 IR 준비 얘기 나눠요',
      TopicCategory.startup,
      12,
      108,
    ),
    ('u-eunbi', 'pangyo-conf', '포트폴리오 피드백 주고받아요', TopicCategory.design, 60, 60),
    ('u-kang', 'pangyo-conf', '컨퍼런스 네트워킹 팁 공유', TopicCategory.other, 8, 52),
    ('u-eunbi', 'yeonnam', 'Figma 변수 기능 써보신 분', TopicCategory.design, 35, 85),
    ('u-gunwoo', 'yeonnam', '데이터 분석 독학 중이에요', TopicCategory.study, 50, 130),
    ('u-nari', 'sinchon-lib', '영어 회화 스터디 같이 할 분', TopicCategory.study, 20, 100),
    ('u-gunwoo', 'sinchon-lib', '졸업 후 첫 직장 고민', TopicCategory.career, 15, 45),
  ];

  static List<Checkin> checkins(DateTime now) => [
    for (final (i, (uid, spotId, topic, category, ago, _)) in _cards.indexed)
      () {
        final u = users.firstWhere((u) => u.uid == uid);
        return Checkin(
          id: 'c-$i',
          uid: uid,
          spotId: spotId,
          nickname: u.nickname,
          jobTag: u.jobTag,
          topic: topic,
          category: category,
          startedAt: now.subtract(Duration(minutes: ago)),
          hasTrustBadge: u.hasTrustBadge,
        );
      }(),
  ];

  /// 내 신청 상대가 수락할지(데모 시나리오). 없는 uid는 수락.
  static const rejectingUids = {'u-taeo', 'u-kang'};

  /// 체크인 직후 나에게 신청을 보내는 사람과 한 마디: (uid, 한 마디, 체크인 후 지연)
  static const incomingRequests = <(String, String, Duration)>[
    ('u-doyun', '저도 같은 고민 중이라 얘기 나눠보고 싶어요!', Duration(seconds: 6)),
    ('u-jaehyun', '주제 보고 반가워서 신청해요. 10분만 얘기해요', Duration(seconds: 40)),
  ];

  /// 빈 스팟에서 "누가 오면 알려줘"를 켰을 때 들어오는 사람
  static const arrivingUid = 'u-hyunsoo';
  static const arrivingTopic = ('초기 창업 공동창업자 찾는 법', TopicCategory.startup);
  static const arrivalDelay = Duration(seconds: 8);

  /// 신청 응답·채팅 답장 지연
  static const responseDelay = Duration(seconds: 5);
  static const replyDelay = Duration(seconds: 2);

  static const greeting = '안녕하세요! 신청 보고 반가웠어요 😊 지금 라운지 어디쯤 계세요?';

  static const replies = [
    '오 저도 그거 궁금했어요. 어떻게 하고 계세요?',
    '좋네요 ㅎㅎ 저는 창가 쪽 긴 테이블에 있어요',
    '아 그건 저도 겪어봤어요. 처음엔 꽤 헤맸는데 문서부터 보는 게 빨랐어요',
    '괜찮으시면 10분 뒤에 커피 한 잔 하면서 얘기할까요?',
    '좋아요! 이따 봬요 👋',
  ];

  /// 이미 지나간 보낸 신청(상태 표시용): (uid, spotId, 한 마디, 상태, 몇 분 전)
  static const pastSent = <(String, String, String, ChatRequestStatus, int)>[
    (
      'u-minseo',
      'seongsu',
      '디자인 시스템 토큰 구조 궁금해요',
      ChatRequestStatus.rejected,
      180,
    ),
    (
      'u-gunwoo',
      'yeonnam',
      '데이터 분석 어떤 걸로 공부하세요?',
      ChatRequestStatus.expired,
      300,
    ),
  ];

  static List<ChatRequest> sentHistory(DateTime now) => [
    for (final (i, (uid, spotId, msg, status, ago)) in pastSent.indexed)
      ChatRequest(
        id: 'r-past-$i',
        fromUid: myUid,
        toUid: uid,
        spotId: spotId,
        toCheckinId: '',
        message: msg,
        status: status,
        createdAt: now.subtract(Duration(minutes: ago)),
        expiresAt: now
            .subtract(Duration(minutes: ago))
            .add(AppLimits.requestExpiry),
      ),
  ];

  /// 지난 대화: (chatId, 상대 uid, 시작 몇 시간 전, 메시지[(내가 보냄?, 텍스트, 몇 분 전)], 안 읽음)
  static const _chats = <(String, String, int, List<(bool, String, int)>, int)>[
    (
      'chat-seojun',
      'u-seojun',
      3,
      [
        (false, '안녕하세요, Flutter 상태관리 주제 보고 신청했어요', 175),
        (true, '반가워요! 요즘 Riverpod 쓰고 있어요', 172),
        (false, 'Notifier로 바꾸면서 코드가 꽤 줄었죠?', 170),
        (true, '네 build()만 남기니까 훨씬 깔끔해요', 168),
        (false, '다음에 또 체크인하시면 얘기해요!', 12),
      ],
      1,
    ),
    (
      'chat-jiwon',
      'u-jiwon',
      26,
      [
        (true, '퍼포먼스 마케팅 1인이신가요?', 1560),
        (false, '네ㅠ 혼자서 다 해요. 혹시 예산 어떻게 나누세요?', 1555),
        (true, '저는 7:3으로 검색광고 위주로 가요', 1550),
        (false, '오 참고할게요. 링크드인 남겨드릴게요!', 1500),
      ],
      0,
    ),
    (
      'chat-left',
      'u-left',
      96,
      [
        (false, '저도 사이드 프로젝트 하고 있어요', 5760),
        (true, '어떤 서비스 만드세요?', 5755),
        (false, '독서 기록 앱이요 ㅎㅎ', 5750),
      ],
      0,
    ),
    // 7일이 지나 목록에서 사라져야 하는 대화
    ('chat-old', 'u-nari', 24 * 8, [(false, '지난주 밋업 재밌었어요', 60 * 24 * 8)], 0),
  ];

  static (List<Chat>, Map<String, List<ChatMessage>>, Map<String, int>) chats(
    DateTime now,
  ) {
    final chats = <Chat>[];
    final messages = <String, List<ChatMessage>>{};
    final unread = <String, int>{};
    for (final (id, uid, hoursAgo, msgs, unreadCount) in _chats) {
      final created = now.subtract(Duration(hours: hoursAgo));
      final list = [
        for (final (i, (mine, text, ago)) in msgs.indexed)
          ChatMessage(
            id: '$id-$i',
            senderUid: mine ? myUid : uid,
            text: text,
            sentAt: now.subtract(Duration(minutes: ago)),
          ),
      ];
      chats.add(
        Chat(
          id: id,
          memberUids: [myUid, uid],
          createdAt: created,
          expiresAt: created.add(AppLimits.chatRetention),
          lastMessage: list.last.text,
          lastMessageAt: list.last.sentAt,
          leftUids: [if (users.any((u) => u.uid == uid && u.deleted)) uid],
        ),
      );
      messages[id] = list;
      unread[id] = unreadCount;
    }
    return (chats, messages, unread);
  }

  /// 최근 쓴 주제 (US-016)
  static const recentTopics = <(String, TopicCategory)>[
    ('Flutter 상태관리 뭐 쓰세요?', TopicCategory.dev),
    ('프리랜서 단가 협상 얘기해요', TopicCategory.career),
    ('성수 점심 같이 고민해요', TopicCategory.other),
  ];
}
