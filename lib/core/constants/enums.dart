/// 하는 일 태그의 묶음. 화면에서 이 순서대로 섹션을 나눠 보여준다.
///
/// - 직무·분야 3묶음: 무슨 일을 하는지(기능·직업). 서로 겹치지 않게 나눴다.
/// - 지금 상태: 어떤 형태로 일하는지·일하지 않는 중인지.
/// 두 축은 함께 해당될 수 있어서(예: 프리랜서 디자이너) 화면에서
/// "가장 잘 나타내는 하나"를 고르게 안내한다. 어디에도 없으면 기타.
enum JobTagGroup {
  business('비즈니스·IT'),
  creative('창작·미디어'),
  professional('전문·현장'),
  status('지금 상태'),
  other('');

  const JobTagGroup(this.label);
  final String label;
}

/// 하는 일 태그 (US-002). 단일 선택, 30개.
/// 이름(name)은 Firestore에 저장되므로 바꾸지 않는다. 순서·라벨은 바꿔도 된다.
enum JobTag {
  // 비즈니스·IT
  developer('개발', JobTagGroup.business),
  designer('디자인', JobTagGroup.business),
  productManager('기획·PM', JobTagGroup.business),
  data('데이터·AI', JobTagGroup.business),
  marketer('마케팅', JobTagGroup.business),
  sales('영업', JobTagGroup.business),
  hr('HR·인사', JobTagGroup.business),
  finance('재무·회계', JobTagGroup.business),
  strategy('경영·컨설팅', JobTagGroup.business),
  operations('운영·CS', JobTagGroup.business),
  legal('법무', JobTagGroup.business),
  engineer('엔지니어링', JobTagGroup.business),

  // 창작·미디어
  writer('작가', JobTagGroup.creative),
  creator('크리에이터', JobTagGroup.creative),
  photoVideo('사진·영상', JobTagGroup.creative),
  artist('예술·음악', JobTagGroup.creative),

  // 전문·현장
  educator('교육·강사', JobTagGroup.professional),
  researcher('연구', JobTagGroup.professional),
  medical('의료·보건', JobTagGroup.professional),
  chef('셰프·요리', JobTagGroup.professional),
  publicSector('공무원·공공', JobTagGroup.professional),
  service('서비스·판매', JobTagGroup.professional),

  // 지금 상태
  freelancer('프리랜서', JobTagGroup.status),
  founder('창업', JobTagGroup.status),
  preparingStartup('창업 준비 중', JobTagGroup.status),
  selfEmployed('자영업', JobTagGroup.status),
  student('학생', JobTagGroup.status),
  jobSeeking('취업 준비 중', JobTagGroup.status),
  onBreak('쉬는 중', JobTagGroup.status),

  other('기타', JobTagGroup.other);

  const JobTag(this.label, this.group);
  final String label;
  final JobTagGroup group;
}

/// 화면에 보이는 하는 일: 기타 + 직접 입력이면 입력한 글자, 아니면 태그 라벨.
String jobLabelOf(JobTag tag, String? custom) =>
    tag == JobTag.other && (custom?.trim().isNotEmpty ?? false)
    ? custom!.trim()
    : tag.label;

/// 키워드 묶음(체크인 화면에서 그룹별로 보여 준다)
enum KeywordGroup {
  work('일·커리어'),
  learning('배움'),
  daily('일상'),
  hobby('취미·문화'),
  other('');

  const KeywordGroup(this.label);
  final String label;
}

/// 주제 키워드 (US-005). 단일 선택, 24개. "기타"를 고르면 직접 입력한다(Checkin.categoryCustom).
/// 이름(name)은 Firestore에 저장되므로 바꾸지 않는다. 순서·라벨은 바꿔도 된다.
enum TopicCategory {
  // 일·커리어
  dev('개발', KeywordGroup.work),
  design('디자인', KeywordGroup.work),
  marketing('마케팅', KeywordGroup.work),
  planning('기획·PM', KeywordGroup.work),
  dataAi('데이터·AI', KeywordGroup.work),
  startup('창업', KeywordGroup.work),
  career('커리어·이직', KeywordGroup.work),
  sideJob('부업·N잡', KeywordGroup.work),
  // 배움
  study('스터디', KeywordGroup.learning),
  language('외국어', KeywordGroup.learning),
  reading('독서', KeywordGroup.learning),
  certificate('자격증·시험', KeywordGroup.learning),
  finance('재테크·투자', KeywordGroup.learning),
  // 일상
  smallTalk('스몰톡', KeywordGroup.daily),
  worry('고민 상담', KeywordGroup.daily),
  food('맛집·카페', KeywordGroup.daily),
  travel('여행', KeywordGroup.daily),
  fitness('운동·건강', KeywordGroup.daily),
  family('육아·가족', KeywordGroup.daily),
  // 취미·문화
  culture('전시·공연', KeywordGroup.hobby),
  movie('영화·드라마', KeywordGroup.hobby),
  music('음악', KeywordGroup.hobby),
  game('게임', KeywordGroup.hobby),
  // 기타 → 직접 입력
  other('기타', KeywordGroup.other);

  const TopicCategory(this.label, this.group);
  final String label;
  final KeywordGroup group;
}

/// 카드에 보이는 키워드. 기타를 고르고 직접 입력했으면 그 글자.
String keywordLabelOf(TopicCategory category, String? custom) =>
    category == TopicCategory.other && (custom?.trim().isNotEmpty ?? false)
    ? custom!.trim()
    : category.label;

/// 신고 사유 (US-010).
enum ReportReason {
  sales('영업'),
  dating('만남 목적'),
  religion('종교 권유'),
  abuse('욕설'),
  other('기타');

  const ReportReason(this.label);
  final String label;
}

/// 대화 요청 상태 (US-007, US-008).
enum ChatRequestStatus { pending, accepted, rejected, expired }

/// 대화 평가 (US-017).
enum ChatReviewRating { good, soso }

/// 신고·차단을 호출한 위치 (IA 글로벌 > 신고).
enum ReportSource { feed, request, chat }
