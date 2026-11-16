import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase에 연결된 실제 모드인지. main.dart에서 Firebase가 준비되면 true로 바꿔 끼운다.
///
/// - false(데모): 저장소가 더미 데이터·시나리오로 시작한다(테스트도 이 모드).
/// - true(실제): 저장소가 비어서 시작하고, Firestore 실시간 데이터로 채워진다(LiveSync).
final liveModeProvider = Provider<bool>((ref) => false);
