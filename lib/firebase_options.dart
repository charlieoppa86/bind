// ⚠️ 임시 파일입니다.
// Firebase 프로젝트를 만든 뒤 아래 명령으로 이 파일을 덮어쓰세요.
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --platforms=android,ios
//
import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase가 아직 설정되지 않았습니다. `flutterfire configure`를 실행하세요.',
  );
}
