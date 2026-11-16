/// 한글 검색: 띄어쓰기·대소문자 무시 + 초성 검색(예: "ㅅㅅ" → "성수").
abstract final class KoreanSearch {
  static const _chosung = [
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];
  static const _hangulStart = 0xAC00;
  static const _hangulEnd = 0xD7A3;
  static const _syllablesPerInitial = 21 * 28;

  /// 띄어쓰기를 지우고 소문자로
  static String normalize(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  /// 글자마다 초성으로 바꾼 문자열(한글이 아니면 그대로)
  static String initials(String s) => String.fromCharCodes(
    normalize(s).runes.map((r) {
      if (r < _hangulStart || r > _hangulEnd) return r;
      return _chosung[(r - _hangulStart) ~/ _syllablesPerInitial].runes.first;
    }),
  );

  static bool _isAllInitials(String q) =>
      q.isNotEmpty &&
      q.runes.every((r) => _chosung.contains(String.fromCharCode(r)));

  /// [text]가 [query]를 포함하는지
  static bool matches(String text, String query) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    if (normalize(text).contains(q)) return true;
    return _isAllInitials(q) && initials(text).contains(q);
  }
}
