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
    // TODO(fcm): FirebaseMessaging.onBackgroundMessage 등록, 권한 요청, 토큰 저장
    return true;
  } on UnsupportedError catch (e) {
    debugPrint('[BIND] ${e.message} — 데모 모드로 실행합니다.');
    return false;
  }
}
