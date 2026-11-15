import 'package:bind_app/core/location/location.dart';
import 'package:bind_app/core/utils/geo.dart';

/// 성수 워크라운지 앞(방 '성수 워크라운지'까지 약 40m, '성수 북카페 2층'까지 약 170m)
const seongsuFront = GeoPoint(37.54425, 127.05560);

class FakeLocationService implements LocationService {
  FakeLocationService([this.point = seongsuFront]);

  GeoPoint point;

  @override
  Future<(LocationStatus, GeoPoint?)> current({required bool request}) async =>
      (LocationStatus.ready, point);

  @override
  Future<void> openSettings() async {}
}
