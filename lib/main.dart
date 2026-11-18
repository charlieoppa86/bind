import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/firebase_bootstrap.dart';
import 'core/push/push_background.dart';
import 'core/push/push_platform.dart';
import 'data/account/account_repository.dart';
import 'data/live/live_mode.dart';
import 'data/place/place_search.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await initFirebase();
  if (firebaseReady) {
    // 백그라운드·종료 상태 알림 처리(runApp 전에 등록해야 한다)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(
    ProviderScope(
      overrides: [
        // Firebase가 연결되면 로그인·프로필은 Firebase Auth/Firestore,
        // 장소 검색은 카카오 검색(Cloud Functions)을 쓴다.
        if (firebaseReady) ...[
          liveModeProvider.overrideWithValue(true),
          accountRepositoryProvider.overrideWithValue(
            FirebaseAccountRepository(),
          ),
          placeSearchProvider.overrideWithValue(FunctionsPlaceSearch()),
          pushPlatformProvider.overrideWithValue(FirebasePushPlatform()),
        ],
      ],
      child: const BindApp(),
    ),
  );
}
