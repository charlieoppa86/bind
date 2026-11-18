import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Firebase 초기화. `flutterfire configure` 전에는 경고만 남기고
/// Firebase 없이 화면 흐름(데모 모드)으로 실행한다.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError catch (e) {
    debugPrint('[BIND] ${e.message} — 데모 모드로 실행합니다.');
    return false;
  }
  await _activateAppCheck();
  // TODO(fcm): FirebaseMessaging.onBackgroundMessage 등록, 권한 요청, 토큰 저장
  return true;
}

/// App Check: 정식 BIND 앱에서 온 요청인지 Firebase가 확인하게 한다.
///
/// - 출시 빌드: Android Play Integrity, iOS App Attest(안 되면 DeviceCheck)
/// - 개발 빌드: 디버그 제공자. 처음 실행하면 logcat/Xcode 콘솔에 디버그 토큰이 찍히고,
///   Firebase 콘솔 > App Check > 앱 > 디버그 토큰 관리에 등록해야 통과한다.
///
/// 지금은 토큰 발급·측정만 한다. 콘솔에서 확인된 요청 비율을 보고 Firestore·Functions
/// 적용(enforce)을 켠다(켜기 전에는 확인 안 된 요청도 통과한다).
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  } catch (e) {
    // App Check 실패로 앱 시작이 막히지 않게 한다(적용 전에는 요청도 통과한다).
    debugPrint('[BIND] App Check 시작 실패: $e');
  }
}
