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

/// 키워드 묶음(체크인 화면에서 이 순서대로 보여 준다). 2026-11-23: 커리어·일상·스터디 3개.
/// 묶음은 화면에서만 쓰고 Firestore에 저장하지 않는다.
enum KeywordGroup {
  career('커리어'),
  daily('일상'),
  study('스터디');

  const KeywordGroup(this.label);
  final String label;
}

/// 주제 키워드 (US-005). 단일 선택, 35개(커리어 12 / 일상 12 / 스터디 11).
/// "기타"(일상 묶음 맨 끝)를 고르면 직접 입력한다(Checkin.categoryCustom).
/// 이름(name)은 Firestore에 저장되므로 바꾸지 않는다. 순서·라벨·묶음은 바꿔도 된다.
/// 연애·만남 키워드는 넣지 않는다(US-W08).
enum TopicCategory {
  // 커리어
  dev('개발', KeywordGroup.career),
  design('디자인', KeywordGroup.career),
  marketing('마케팅', KeywordGroup.career),
  planning('기획·PM', KeywordGroup.career),
  dataAi('데이터·AI', KeywordGroup.career),
  sales('영업·세일즈', KeywordGroup.career),
  startup('창업', KeywordGroup.career),
  freelance('프리랜서', KeywordGroup.career),
  career('이직·커리어', KeywordGroup.career),
  jobSeeking('취업 준비', KeywordGroup.career),
  sideJob('부업·N잡', KeywordGroup.career),
  networking('네트워킹', KeywordGroup.career),
  // 일상
  smallTalk('스몰톡', KeywordGroup.daily),
  worry('고민 상담', KeywordGroup.daily),
  food('맛집·카페', KeywordGroup.daily),
  travel('여행', KeywordGroup.daily),
  fitness('운동·건강', KeywordGroup.daily),
  family('육아·가족', KeywordGroup.daily),
  pet('반려동물', KeywordGroup.daily),
  culture('전시·공연', KeywordGroup.daily),
  movie('영화·드라마', KeywordGroup.daily),
  music('음악', KeywordGroup.daily),
  game('게임', KeywordGroup.daily),
  other('기타', KeywordGroup.daily),
  // 스터디
  study('모각공', KeywordGroup.study),
  language('외국어', KeywordGroup.study),
  certificate('자격증', KeywordGroup.study),
  civilExam('공무원·고시', KeywordGroup.study),
  major('전공·학교 공부', KeywordGroup.study),
  coding('코딩 공부', KeywordGroup.study),
  reading('독서', KeywordGroup.study),
  writing('글쓰기', KeywordGroup.study),
  finance('재테크 공부', KeywordGroup.study),
  routine('공부 루틴·습관', KeywordGroup.study),
  lecture('강의·세미나', KeywordGroup.study);

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

/// 대화방 종류 (US-009 1:1, US-025 그룹).
/// 이름(name)은 Firestore `chats/{id}.type`에 저장되므로 바꾸지 않는다.
enum ChatType {
  /// 대화 요청을 수락하면 열리는 1:1 채팅
  direct('1:1 채팅'),

  /// 체크인할 때 연 그룹 채팅. 같은 장소 사람이 요청 없이 들어온다.
  group('그룹 채팅');

  const ChatType(this.label);
  final String label;
}

/// 연령대(2026-11-25). 체크인할 때 필수로 고르고, 주제 카드에 보인다.
/// 이름(name)은 Firestore에 저장되므로 바꾸지 않는다. 만 19세는 20대를 고른다.
enum AgeBand {
  twenties('20대'),
  thirties('30대'),
  forties('40대'),
  fiftiesPlus('50대 이상');

  const AgeBand(this.label);
  final String label;
}

/// 성별(2026-11-25). 체크인할 때 필수로 고르고, 주제 카드에 보인다.
/// 이름(name)은 Firestore에 저장되므로 바꾸지 않는다.
enum Gender {
  male('남성'),
  female('여성');

  const Gender(this.label);
  final String label;
}

/// 카드에 보이는 "30대 · 여성". 고르기 전에 올린 카드(이전 앱)는 빈 문자열.
String demographicLabelOf(AgeBand? age, Gender? gender) =>
    [?age?.label, ?gender?.label].join(' · ');
