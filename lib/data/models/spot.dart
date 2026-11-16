import 'place.dart';

/// `spots/{placeId}` — 사람들이 체크인한 장소. 카카오 장소 검색으로 고른다.
///
/// 같은 카카오 장소([placeId])로 체크인한 사람끼리 서로의 주제 카드를 보고
/// 대화를 요청한다. 체류 시간 제한은 없다. 체크아웃할 때까지 카드가 보인다.
/// Firestore에서는 문서 id를 카카오 장소 ID로 써서 찾기·만들기를 한 번에 한다.
class Spot {
  const Spot({
    required this.id,
    required this.placeId,
    required this.name,
    this.address = '',
    this.category = '',
    this.creatorUid,
    this.createdAt,
    this.active = true,
    this.activeCount,
  });

  factory Spot.fromMap(String id, Map<String, dynamic> map) => Spot(
    id: id,
    placeId: map['placeId'] as String? ?? id,
    name: map['name'] as String? ?? '',
    address: map['address'] as String? ?? '',
    category: map['category'] as String? ?? '',
    creatorUid: map['creatorUid'] as String?,
    active: map['active'] as bool? ?? true,
    activeCount: map['activeCount'] as int? ?? 0,
  );

  final String id;

  /// 카카오 장소 ID(같은 장소 판정 기준)
  final String placeId;
  final String name;
  final String address;
  final String category;

  /// 이 장소에 처음 체크인한 사람
  final String? creatorUid;
  final DateTime? createdAt;
  final bool active;

  /// 지금 체크인한 사람 수. Cloud Functions가 갱신한다(실제 모드).
  /// 데모 모드에서는 null이고, 인원은 체크인 목록으로 센다.
  final int? activeCount;

  /// 빠른 선택 칩에서 다시 고를 때 쓰는 검색 결과 모양
  Place toPlace() =>
      Place(id: placeId, name: name, address: address, category: category);
}
