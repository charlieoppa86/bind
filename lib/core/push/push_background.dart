import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';

/// 백그라운드·종료 상태에서 받은 알림. 별도 isolate에서 돈다.
///
/// 서버는 notification(제목·본문)이 있는 메시지를 보내서 OS가 알림을 직접 띄운다.
/// 사용자가 그 알림을 누르면 앱이 열리면서 onMessageOpenedApp / getInitialMessage로
/// 같은 메시지가 다시 들어오고, 그때 PushController가 상태에 넣고 화면을 연다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
