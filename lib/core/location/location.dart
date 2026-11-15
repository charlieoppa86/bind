import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/geo.dart';

/// 위치 상태. 위치는 주변 방(반경 안) 판정에만 쓰고 서버에 저장하지 않는다.
enum LocationStatus {
  /// 아직 확인 전
  unknown,
  loading,

  /// 권한 거부(다시 물어볼 수 있음)
  denied,

  /// 권한 영구 거부 → 설정에서 켜야 함
  deniedForever,

  /// 기기 위치 서비스 꺼짐
  serviceOff,
  ready,
}

class LocationState {
  const LocationState({
    this.status = LocationStatus.unknown,
    this.point,
    this.simulatedLabel,
  });

  final LocationStatus status;
  final GeoPoint? point;

  /// 개발용 가상 위치를 쓰는 중이면 그 이름
  final String? simulatedLabel;

  bool get isReady => status == LocationStatus.ready && point != null;

  /// 새로 읽는 중이어도 직전 위치가 있으면 그걸로 목록을 보여준다.
  bool get hasPoint =>
      point != null &&
      (status == LocationStatus.ready || status == LocationStatus.loading);
}

/// 기기 위치를 읽는 창구. 테스트에서는 가짜로 바꿔 끼운다.
abstract interface class LocationService {
  /// 권한 확인(필요하면 요청) 후 현재 위치. 실패하면 상태만 돌려준다.
  Future<(LocationStatus, GeoPoint?)> current({required bool request});

  Future<void> openSettings();
}

class DeviceLocationService implements LocationService {
  @override
  Future<(LocationStatus, GeoPoint?)> current({required bool request}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (LocationStatus.serviceOff, null);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return (LocationStatus.denied, null);
      case LocationPermission.deniedForever:
        return (LocationStatus.deniedForever, null);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return (LocationStatus.ready, GeoPoint(p.latitude, p.longitude));
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (_) => DeviceLocationService(),
);

class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  /// 현재 위치를 다시 읽는다. [request]면 권한이 없을 때 요청한다.
  Future<void> refresh({bool request = false}) async {
    if (state.simulatedLabel != null) return;
    state = LocationState(status: LocationStatus.loading, point: state.point);
    try {
      final (status, point) = await ref
          .read(locationServiceProvider)
          .current(request: request);
      state = LocationState(status: status, point: point);
    } catch (_) {
      state = const LocationState(status: LocationStatus.serviceOff);
    }
  }

  Future<void> openSettings() =>
      ref.read(locationServiceProvider).openSettings();

  /// 개발용: 가상 위치로 바꾼다(null이면 기기 위치로 복귀).
  Future<void> simulate(GeoPoint? point, {String? label}) async {
    if (point == null) {
      state = const LocationState();
      await refresh();
      return;
    }
    state = LocationState(
      status: LocationStatus.ready,
      point: point,
      simulatedLabel: label ?? '가상 위치',
    );
  }
}

final locationProvider = NotifierProvider<LocationController, LocationState>(
  LocationController.new,
);
