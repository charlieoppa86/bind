import '../../core/utils/korean_search.dart';

/// `spots/{spotId}` — 사용자가 자유롭게 입력해 연 장소.
///
/// 같은 장소를 입력한 사람끼리 서로의 주제 카드를 보고 대화를 신청한다.
/// 장소 이름은 띄어쓰기·대소문자를 무시하고 같으면 같은 장소로 본다([key]).
/// 체류 시간 제한은 없다. 체크아웃할 때까지 카드가 보인다.
class Spot {
  const Spot({
    required this.id,
    required this.name,
    this.creatorUid,
    this.createdAt,
    this.active = true,
  });

  factory Spot.fromMap(String id, Map<String, dynamic> map) => Spot(
    id: id,
    name: map['name'] as String? ?? '',
    creatorUid: map['creatorUid'] as String?,
    active: map['active'] as bool? ?? true,
  );

  final String id;

  /// 사용자가 입력한 장소 이름(처음 연 사람의 표기)
  final String name;

  /// 장소를 처음 입력해 연 사람
  final String? creatorUid;
  final DateTime? createdAt;
  final bool active;

  /// 같은 장소 판정용 키(띄어쓰기·대소문자 무시). Firestore에서는 이 값으로 찾는다.
  String get key => keyOf(name);

  static String keyOf(String name) => KoreanSearch.normalize(name);
}
