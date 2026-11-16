import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'checkin_repository.dart';
import 'request_repository.dart';
import 'safety_repository.dart';

export 'checkin_repository.dart';
export 'request_repository.dart';
export 'safety_repository.dart';

/// 체크인 저장소. 실제 모드에서만 쓰인다(Firestore 인스턴스는 처음 쓸 때 만든다).
final checkinRepositoryProvider = Provider<CheckinRepository>(
  (ref) => CheckinRepository(),
);

/// 대화 요청·채팅방 저장소(실제 모드)
final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(),
);

/// 차단·신고·평가 저장소(실제 모드)
final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(),
);
