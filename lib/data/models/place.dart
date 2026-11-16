/// 장소 검색 결과 한 건(카카오 로컬 "키워드로 장소 검색").
///
/// [id]는 카카오 장소 ID다. 같은 ID로 체크인한 사람끼리 같은 장소로 묶인다.
/// 서버(Cloud Functions `searchPlaces`)가 카카오 응답을 아래 모양으로 줄여서 준다.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    this.category = '',
    this.lat,
    this.lng,
  });

  factory Place.fromMap(Map<String, dynamic> map) => Place(
    id: '${map['id']}',
    name: map['name'] as String? ?? '',
    address: map['address'] as String? ?? '',
    category: map['category'] as String? ?? '',
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
  );

  /// 카카오 장소 ID
  final String id;

  /// 장소 이름(예: 성수 워크라운지)
  final String name;

  /// 도로명 주소(없으면 지번 주소)
  final String address;

  /// 짧은 업종(예: 카페, 공유오피스). 카카오 category_name의 마지막 단계
  final String category;
  final double? lat;
  final double? lng;

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
