/// `spots/{spotId}` — 특정 장소에 사용자가 연 대화방.
///
/// 장소 반경 [AppLimits.roomRadiusMeters] 안에 있는 사람만 찾고 입장할 수 있다.
/// 처음 연 사람([creatorUid])이 입장 PIN을 만든다. PIN은 클라이언트가 읽을 수 없도록
/// 비공개 문서 `spotSecrets/{spotId}`에 두고 Cloud Functions에서 검증하며,
/// 개설자 본인에게만 내려준다.
class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.creatorUid,
    this.createdAt,
    this.isEvent = false,
    this.active = true,
  });

  factory Spot.fromMap(String id, Map<String, dynamic> map) => Spot(
    id: id,
    name: map['name'] as String? ?? '',
    address: map['address'] as String? ?? '',
    latitude: (map['lat'] as num?)?.toDouble() ?? 0,
    longitude: (map['lng'] as num?)?.toDouble() ?? 0,
    creatorUid: map['creatorUid'] as String?,
    isEvent: map['isEvent'] as bool? ?? false,
    active: map['active'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String address;

  /// 방의 기준 위치(장소 좌표). 반경 판정에만 쓴다.
  final double latitude;
  final double longitude;

  /// 방을 처음 연 사람. PIN을 볼 수 있다.
  final String? creatorUid;
  final DateTime? createdAt;

  /// 행사장에서 연 방
  final bool isEvent;
  final bool active;
}
