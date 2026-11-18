import 'app_limits.dart';
import 'enums.dart';

/// 키워드별 예시 주제 (US-014). 키워드당 최대 [AppLimits.topicExamplesPerCategory]개.
const Map<TopicCategory, List<String>> topicExamples = {
  TopicCategory.dev: [
    'Flutter 상태관리 뭐 쓰세요?',
    '사이드 프로젝트 백엔드 고민 들어주세요',
    'AI 코딩 도구 실무에서 어떻게 써요?',
    '주니어 코드리뷰 문화 얘기해요',
    '프리랜서 개발 단가 어떻게 정하세요',
  ],
  TopicCategory.design: [
    '디자인 시스템 처음 만드는 중이에요',
    '포트폴리오 피드백 주고받아요',
    'Figma 변수 기능 써보신 분',
    '개발자랑 협업할 때 꿀팁',
    '요즘 영감 받는 서비스 공유해요',
  ],
  TopicCategory.marketing: [
    '1인 마케터 예산 배분 고민',
    '퍼포먼스 광고 요즘 효율 어때요',
    '브랜드 콘텐츠 기획 얘기해요',
    'B2B 리드 모으는 방법 궁금해요',
    'CRM 메시지 문구 같이 봐요',
  ],
  TopicCategory.startup: [
    '초기 창업 공동창업자 찾는 법',
    '첫 투자 IR 준비 얘기 나눠요',
    'MVP 검증 어떻게 하셨어요',
    '1인 창업 번아웃 관리',
    '정부지원사업 써본 경험 공유',
  ],
  TopicCategory.career: [
    '이직 준비 중인 분 얘기해요',
    '연봉 협상 경험 듣고 싶어요',
    '프리랜서 전향 고민 중이에요',
    '사이드잡 병행하는 분 계세요',
    '커리어 피벗 해보신 분',
  ],
  TopicCategory.study: [
    '영어 회화 스터디 같이 할 분',
    '자격증 공부 루틴 공유해요',
    '책 한 권 읽고 얘기 나눠요',
    '데이터 분석 독학 중이에요',
    '집중 잘 되는 공부법 궁금해요',
  ],
  TopicCategory.culture: ['주말 전시 추천 받아요', '요즘 볼 만한 공연 있어요?', '팝업스토어 다녀오신 분'],
  TopicCategory.other: [
    '점심 메뉴 같이 고민해요',
    '재택 vs 출근 어떤 게 좋아요',
    '생산성 앱 뭐 쓰세요?',
    '혼자 일할 때 루틴 공유해요',
    '아무 얘기나 10분 수다',
  ],
  TopicCategory.planning: [
    '기획서 피드백 주고받아요',
    '우선순위 정하는 법 얘기해요',
    'PM으로 커리어 전환 고민 중이에요',
  ],
  TopicCategory.dataAi: ['LLM 업무에 어떻게 쓰세요?', '데이터 분석 독학 중이에요', 'AI 같이 공부해요'],
  TopicCategory.sideJob: [
    '퇴근 후 부업 뭐 하세요?',
    '프리랜서 첫 계약 경험 나눠요',
    '사이드 수익 만들기 얘기해요',
  ],
  TopicCategory.language: ['영어 회화 같이 연습해요', '일본어 독학 중이에요', '외국어 공부 루틴 공유해요'],
  TopicCategory.reading: ['요즘 읽는 책 얘기해요', '책 한 권 추천해 주세요', '독서 모임 해보신 분'],
  TopicCategory.certificate: [
    '자격증 시험 준비 같이 해요',
    '공부 집중 잘 되는 법 나눠요',
    '시험 끝나고 뭐 하세요?',
  ],
  TopicCategory.finance: ['사회초년생 재테크 얘기해요', '가계부 어떻게 쓰세요?', '연말정산 꿀팁 나눠요'],
  TopicCategory.smallTalk: ['가벼운 스몰톡이 하고 싶어요', '잠깐 쉬면서 얘기해요', '오늘 하루 어땠어요?'],
  TopicCategory.worry: ['요즘 고민 하나 들어주세요', '이직할지 남을지 고민돼요', '번아웃 어떻게 넘기셨어요?'],
  TopicCategory.food: ['근처 점심 맛집 공유해요', '좋아하는 카페 추천해 주세요', '디저트 맛집 얘기해요'],
  TopicCategory.travel: ['다음 여행지 추천해 주세요', '혼자 여행 다녀오신 분', '주말 근교 나들이 어디 가세요?'],
  TopicCategory.fitness: ['퇴근 후 운동 뭐 하세요?', '러닝 같이 시작해요', '건강 루틴 공유해요'],
  TopicCategory.family: [
    '육아하면서 일하는 얘기 나눠요',
    '아이랑 갈 만한 곳 추천해요',
    '부모님 선물 뭐가 좋을까요?',
  ],
  TopicCategory.movie: ['요즘 보는 드라마 얘기해요', '최근 본 영화 추천해 주세요', 'OTT 뭐 보세요?'],
  TopicCategory.music: ['요즘 듣는 노래 공유해요', '공연 다녀오신 분', '악기 배우는 중이에요'],
  TopicCategory.game: ['요즘 하는 게임 얘기해요', '보드게임 좋아하세요?', '게임 같이 할 분'],
};

/// 이용 규칙 3줄 (US-003)
List<String> get communityRules => [
  '주제에 대한 대화만 나눠요.',
  '영업·홍보나 전도 등 종교 권유는 금지예요.',
  '서로 다른 ${AppLimits.reportsUntilSuspension}명에게 신고되면 이용이 정지돼요.',
];
