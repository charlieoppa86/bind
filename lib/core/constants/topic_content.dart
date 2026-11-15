import 'app_limits.dart';
import 'enums.dart';

/// 카테고리별 예시 주제 (US-014). 카테고리당 [AppLimits.topicExamplesPerCategory]개.
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
  TopicCategory.culture: [
    '오늘 본 영화 얘기해요',
    '요즘 듣는 플레이리스트 공유',
    '러닝 크루 찾고 있어요',
    '성수 맛집 추천해 주세요',
    '주말 전시 추천 받아요',
  ],
  TopicCategory.other: [
    '점심 메뉴 같이 고민해요',
    '재택 vs 출근 어떤 게 좋아요',
    '생산성 앱 뭐 쓰세요?',
    '혼자 일할 때 루틴 공유해요',
    '아무 얘기나 10분 수다',
  ],
};

/// 이용 규칙 3줄 (US-003)
List<String> get communityRules => [
  '주제에 대한 대화만 나눠요.',
  '영업·홍보나 이성 만남 목적의 접근은 금지예요.',
  '서로 다른 ${AppLimits.reportsUntilSuspension}명에게 신고되면 이용이 정지돼요.',
];
