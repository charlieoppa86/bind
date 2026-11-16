/// 직무 태그 (US-002). 단일 선택.
enum JobTag {
  developer('개발'),
  designer('디자인'),
  marketer('마케팅'),
  founder('창업'),
  student('학생'),
  other('기타');

  const JobTag(this.label);
  final String label;
}

/// 주제 카테고리 (US-005). 단일 선택.
///
/// 연애·만남 카테고리는 영구 제외(US-W08). 절대 추가하지 않는다.
/// NOTE: 문서에 카테고리 목록이 확정돼 있지 않아 초안으로 둔 값이다.
enum TopicCategory {
  dev('개발'),
  design('디자인'),
  marketing('마케팅'),
  startup('창업'),
  career('커리어·이직'),
  study('스터디'),
  culture('문화·취미'),
  other('기타');

  const TopicCategory(this.label);
  final String label;
}

/// 신고 사유 (US-010).
enum ReportReason {
  sales('영업'),
  dating('만남 목적'),
  abuse('욕설'),
  other('기타');

  const ReportReason(this.label);
  final String label;
}

/// 대화 신청 상태 (US-007, US-008).
enum ChatRequestStatus { pending, accepted, rejected, expired }

/// 대화 평가 (US-017).
enum ChatReviewRating { good, soso }

/// 신고·차단을 호출한 위치 (IA 글로벌 > 신고).
enum ReportSource { feed, request, chat }
