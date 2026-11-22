import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../models/checkin.dart';
import '../models/safety.dart';
import '../models/spot.dart';
import 'demo_store.dart';

// 화면은 demoStoreProvider를 통째로 watch하지 않고 아래 provider만 구독한다.
//
// - 각 provider는 자기 데이터 묶음(DemoPart)의 버전만 select로 지켜본다.
//   다른 묶음이 바뀌면 다시 계산하지 않는다.
// - Provider는 이전 값과 같으면(==) 알리지 않는다. 숫자·bool·문자열·같은 객체는
//   값이 그대로면 위젯이 다시 그려지지 않는다.
// - 시간 표시(남은 시간, n분 전)는 clockProvider를 보는 작은 위젯만 다시 그린다.
//
// TODO(firebase): 이 파일의 provider를 Firestore 스트림 기반으로 바꾸면
// 화면 코드는 그대로 둘 수 있다.

DemoDb _db(Ref ref) => ref.read(demoStoreProvider);

/// [parts] 묶음의 버전을 구독한다(바뀐 묶음일 때만 다시 계산).
void _watch(Ref ref, Iterable<DemoPart> parts) {
  for (final p in parts) {
    ref.watch(demoStoreProvider.select((db) => db.rev.of(p)));
  }
}

// ── 시계 ──────────────────────────────────────────────

/// 시간 표시용 현재 시각. 30초마다 바뀐다.
class Clock extends Notifier<DateTime> {
  static const interval = Duration(seconds: 30);

  @override
  DateTime build() {
    final timer = Timer.periodic(interval, (_) => state = DateTime.now());
    ref.onDispose(timer.cancel);
    return DateTime.now();
  }
}

final clockProvider = NotifierProvider<Clock, DateTime>(Clock.new);

// ── 프로필 ────────────────────────────────────────────

final meProvider = Provider<AppUser?>((ref) {
  _watch(ref, const [DemoPart.profile]);
  return _db(ref).me;
});

/// 온보딩 1단계에서 입력해 둔 값 (닉네임, 하는 일, 직접 입력)
final draftProfileProvider = Provider<(String?, JobTag?, String?)>((ref) {
  _watch(ref, const [DemoPart.profile]);
  final db = _db(ref);
  return (db.draftNickname, db.draftJobTag, db.draftJobCustom);
});

final isPlusActiveProvider = Provider<bool>((ref) {
  _watch(ref, const [DemoPart.profile]);
  return _db(ref).isPlusActive;
});

final plusAutoRenewProvider = Provider<bool>((ref) {
  _watch(ref, const [DemoPart.profile]);
  return _db(ref).plusAutoRenew;
});

final topicLimitProvider = Provider<int>((ref) {
  _watch(ref, const [DemoPart.profile]);
  return _db(ref).topicLimit;
});

/// 다른 사람(또는 나). 좋았어요 수가 바뀌는 평가(chats)도 함께 본다.
final userProvider = Provider.family<AppUser?, String>((ref, uid) {
  _watch(ref, const [DemoPart.profile, DemoPart.chats]);
  return _db(ref).user(uid);
});

// ── 장소·체크인 ───────────────────────────────────────

final spotProvider = Provider.family<Spot?, String>((ref, id) {
  _watch(ref, const [DemoPart.places]);
  return _db(ref).spot(id);
});

/// 이 카카오 장소로 이미 열린 장소(검색 결과에 "지금 n명" 표시용)
final spotByPlaceIdProvider = Provider.autoDispose.family<Spot?, String>((
  ref,
  placeId,
) {
  _watch(ref, const [DemoPart.places]);
  return _db(ref).spotByPlaceId(placeId);
});

final isCreatorProvider = Provider.family<bool, String>((ref, spotId) {
  _watch(ref, const [DemoPart.places]);
  return _db(ref).isCreator(spotId);
});

/// 장소에 지금 있는 사람 수(나 포함)
final headcountProvider = Provider.family<int, String>((ref, spotId) {
  _watch(ref, const [DemoPart.checkins]);
  return _db(ref).headcount(spotId, DateTime.now());
});

final activeSpotsProvider = Provider<List<Spot>>((ref) {
  _watch(ref, const [DemoPart.places, DemoPart.checkins]);
  return _db(ref).activeSpots(DateTime.now());
});

final recentSpotsProvider = Provider<List<Spot>>((ref) {
  _watch(ref, const [DemoPart.places]);
  return _db(ref).recentSpots;
});

final myCheckinsProvider = Provider<List<Checkin>>((ref) {
  _watch(ref, const [DemoPart.checkins]);
  return _db(ref).myCheckins(DateTime.now());
});

/// 지금 체크인한 장소 id(체크인 전이면 null)
final mySpotIdProvider = Provider<String?>(
  (ref) => ref.watch(myCheckinsProvider).firstOrNull?.spotId,
);

final checkinProvider = Provider.family<Checkin?, String>((ref, id) {
  _watch(ref, const [DemoPart.checkins]);
  return _db(ref).checkin(id);
});

/// 같은 장소의 다른 사람 카드(차단 제외)
final feedProvider = Provider.family<List<Checkin>, String>((ref, spotId) {
  _watch(ref, const [DemoPart.checkins, DemoPart.blocks]);
  return _db(ref).feed(spotId, DateTime.now());
});

final recentTopicsProvider = Provider<List<(String, TopicCategory)>>((ref) {
  _watch(ref, const [DemoPart.topics]);
  return List.unmodifiable(_db(ref).recentTopics);
});

// ── 대화 요청 ─────────────────────────────────────────

final receivedRequestsProvider = Provider<List<ChatRequest>>((ref) {
  _watch(ref, const [DemoPart.requests, DemoPart.blocks]);
  return _db(ref).received();
});

final sentRequestsProvider = Provider<List<ChatRequest>>((ref) {
  _watch(ref, const [DemoPart.requests]);
  return _db(ref).sent();
});

/// 하단 탭 배지: 수락을 기다리는 받은 요청 수
final pendingReceivedCountProvider = Provider<int>(
  (ref) => ref
      .watch(receivedRequestsProvider)
      .where((r) => r.status == ChatRequestStatus.pending)
      .length,
);

final requestProvider = Provider.family<ChatRequest?, String>((ref, id) {
  _watch(ref, const [DemoPart.requests]);
  return _db(ref).request(id);
});

/// 이 사람에게 보낸, 아직 답을 기다리는 요청
final pendingToProvider = Provider.family<ChatRequest?, String>((ref, uid) {
  _watch(ref, const [DemoPart.requests]);
  return _db(ref).pendingTo(uid);
});

final sentTodayProvider = Provider<int>((ref) {
  _watch(ref, const [DemoPart.requests]);
  return _db(ref).sentToday(DateTime.now());
});

// ── 채팅 ──────────────────────────────────────────────

final visibleChatsProvider = Provider<List<Chat>>((ref) {
  _watch(ref, const [DemoPart.chats, DemoPart.blocks]);
  return _db(ref).visibleChats(DateTime.now());
});

final chatProvider = Provider.family<Chat?, String>((ref, id) {
  _watch(ref, const [DemoPart.chats]);
  return _db(ref).chat(id);
});

/// 이 사람과 열려 있는 대화방 id(없으면 null)
final chatIdWithProvider = Provider.family<String?, String>((ref, uid) {
  _watch(ref, const [DemoPart.chats, DemoPart.blocks]);
  return _db(ref).chatWith(uid, DateTime.now())?.id;
});

/// 이 그룹 채팅에 내가 들어가 있는지(US-025)
final isGroupMemberProvider = Provider.family<bool, String>((ref, chatId) {
  _watch(ref, const [DemoPart.chats]);
  return _db(ref).chat(chatId)?.memberUids.contains(DemoDb.myUid) ?? false;
});

/// 대화방 하나의 메시지. 그 방의 메시지 버전만 본다.
final messagesProvider = Provider.family<List<ChatMessage>, String>((
  ref,
  chatId,
) {
  ref.watch(demoStoreProvider.select((db) => db.rev.chat(chatId)));
  return List.unmodifiable(_db(ref).messages[chatId] ?? const []);
});

final unreadProvider = Provider.family<int, String>((ref, chatId) {
  _watch(ref, const [DemoPart.chats]);
  return _db(ref).unread[chatId] ?? 0;
});

/// 하단 탭 배지: 안 읽은 메시지 합계
final unreadTotalProvider = Provider<int>((ref) {
  _watch(ref, const [DemoPart.chats, DemoPart.blocks]);
  return _db(ref).unreadTotal(DateTime.now());
});

// ── 차단 ──────────────────────────────────────────────

final blocksProvider = Provider<List<Block>>((ref) {
  _watch(ref, const [DemoPart.blocks]);
  return _db(ref).blocks.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final isBlockedProvider = Provider.family<bool, String>((ref, uid) {
  _watch(ref, const [DemoPart.blocks]);
  return _db(ref).isBlocked(uid);
});
