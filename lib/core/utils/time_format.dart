/// 화면에 보이는 시간 문구 포맷.
abstract final class TimeFormat {
  /// 남은 시간: "2시간 10분 남음" / "8분 남음" / "곧 끝나요"
  static String remaining(Duration d) {
    if (d.inMinutes < 1) return '곧 끝나요';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m분 남음';
    if (m == 0) return '$h시간 남음';
    return '$h시간 $m분 남음';
  }

  /// 오전/오후 h:mm
  static String clock(DateTime t) {
    final am = t.hour < 12;
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    return '${am ? '오전' : '오후'} $h12:$mm';
  }

  /// 목록용 상대 시간: 방금 / n분 전 / 오후 3:10 / 어제 / 11월 12일
  static String relative(DateTime t, DateTime now) {
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final days = today.difference(day).inDays;
    if (days == 0) return clock(t);
    if (days == 1) return '어제';
    return date(t);
  }

  /// 11월 12일
  static String date(DateTime t) => '${t.month}월 ${t.day}일';

  /// 2026년 11월 12일
  static String fullDate(DateTime t) => '${t.year}년 ${t.month}월 ${t.day}일';
}
