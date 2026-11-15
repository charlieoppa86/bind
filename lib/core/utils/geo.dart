import 'dart:math' as math;

/// 위도·경도 한 점
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// 두 지점 사이 거리(m, 하버사인)
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// 북쪽으로 [north]m, 동쪽으로 [east]m 옮긴 지점(짧은 거리용 근사)
  GeoPoint offset({double north = 0, double east = 0}) => GeoPoint(
    latitude + north / 111320,
    longitude + east / (111320 * math.cos(latitude * math.pi / 180)),
  );
}

/// 거리 표시: "80m" / "1.2km"
String formatDistance(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10}m'
    : '${(meters / 1000).toStringAsFixed(1)}km';
