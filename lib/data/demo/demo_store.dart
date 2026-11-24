import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/constants/app_limits.dart';
import '../../core/constants/enums.dart';
import '../../core/notice/in_app_notice.dart';
import '../../features/session/session.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../models/checkin.dart';
import '../models/safety.dart';
import '../live/checkin_repository_provider.dart';
import '../live/live_mode.dart';
import '../models/place.dart';
import '../models/spot.dart';
import 'demo_seed.dart';

/// 데모 모드 데이터 저장소(메모리).
///
/// Firebase 연결 전까지 Firestore 컬렉션(`spots`, `checkins`, `chatRequests`,
/// `chats`, `users/{uid}/blocks`)과 Cloud Functions가 하는 일
/// (코드 검증, 요청 만료, 채팅방 생성)을 흉내 낸다.
/// 상대방의 수락·답장·체크인은 [DemoSeed]의 시나리오대로 몇 초 뒤 일어난다.
/// 저장소 안의 데이터 묶음. 바뀐 묶음의 버전만 올려서,
/// 그 묶음을 구독하는 위젯만 다시 그리게 한다(`demo_providers.dart`).
enum DemoPart {
  /// 내 프로필·온보딩 임시값·BIND+
  profile,

  /// 장소 목록·최근 간 장소
  places,

  /// 체크인(주제 카드)
  checkins,

  /// 대화 요청
  requests,

  /// 대화방 목록·안 읽은 수·평가
  chats,

  /// 차단
  blocks,

  /// 최근 쓴 주제
  topics,
}

/// 묶음별 버전. 값은 앱 전체에서 한 번도 겹치지 않게 올린다
/// (탈퇴로 저장소를 새로 만들어도 이전 값과 같아지지 않도록).
class DemoRev {
  DemoRev() {
    for (final p in DemoPart.values) {
      _parts[p] = ++_counter;
    }
  }

  static int _counter = 0;
  final Map<DemoPart, int> _parts = {};
  final Map<String, int> _chats = {};

  int of(DemoPart part) => _parts[part]!;

  /// 대화방 하나의 메시지 버전
  int chat(String chatId) => _chats[chatId] ?? 0;

  void bump(Iterable<DemoPart> parts, {String? chatId}) {
    for (final p in parts) {
      _parts[p] = ++_counter;
    }
    if (chatId != null) _chats[chatId] = ++_counter;
  }
}

class DemoDb {
  DemoDb._seed(DateTime now)
    : users = {for (final u in DemoSeed.users) u.uid: u},
      spots = [...DemoSeed.spots],
      checkins = DemoSeed.checkins(now),
      requests = DemoSeed.sentHistory(now),
      recentTopics = [...DemoSeed.recentTopics] {
    final (c, m, u) = DemoSeed.chats(now);
    chats = c;
    messages = m;
    unread = u;
  }

  /// 실제(Firebase) 모드: 더미 없이 비어서 시작하고 Firestore 데이터로 채운다.
  DemoDb._empty()
    : users = {},
      spots = [],
      checkins = [],
      requests = [],
      recentTopics = [] {
    chats = [];
    messages = {};
    unread = {};
  }

  static const myUid = DemoSeed.myUid;

  /// 실제 모드에서 실시간으로 지켜보는 장소(이 장소 인원은 체크인 목록으로 센다)
  String? liveSpotId;

  /// 묶음별 버전(바뀐 부분만 다시 그리기용)
  final DemoRev rev = DemoRev();

  /// 온보딩을 마치기 전에는 null
  AppUser? me;

  /// 온보딩 1단계(프로필)에서 입력한 값. 동의까지 마쳐야 [me]가 된다.
  String? draftNickname;
  JobTag? draftJobTag;
  String? draftJobCustom;

  bool plusAutoRenew = false;

  final Map<String, AppUser> users;
  final List<Spot> spots;

  /// 최근 체크인한 장소 id(최신순)
  final List<String> recentSpotIds = [];
  final List<Checkin> checkins;
  final List<ChatRequest> requests;
  late final List<Chat> chats;
  late final Map<String, List<ChatMessage>> messages;
  late final Map<String, int> unread;
  final Set<String> reviewAsked = {};
  final Map<String, Block> blocks = {};
  final Set<String> reportedUids = {};
  final List<(String, TopicCategory)> recentTopics;

  int _seq = 0;
  String nextId(String prefix) => '$prefix-${++_seq}';

  // ── 조회 ────────────────────────────────────────────

  AppUser? user(String uid) => uid == myUid ? me : users[uid];

  Spot? spot(String? id) => spots.where((s) => s.id == id).firstOrNull;

  bool isCreator(String spotId) => spot(spotId)?.creatorUid == myUid;

  /// 이 카카오 장소로 이미 열린 장소(같은 장소 판정)
  Spot? spotByPlaceId(String placeId) =>
      spots.where((s) => s.active && s.placeId == placeId).firstOrNull;

  /// 지금 사람이 있는 장소(사람 많은 순)
  List<Spot> activeSpots(DateTime now) => [
    for (final s in spots)
      if (s.active && headcount(s.id, now) > 0) s,
  ]..sort((a, b) => headcount(b.id, now).compareTo(headcount(a.id, now)));

  List<Spot> get recentSpots => [for (final id in recentSpotIds) ?spot(id)];

  bool isBlocked(String uid) => blocks.containsKey(uid);

  List<Checkin> myCheckins(DateTime now) => [
    for (final c in checkins)
      if (c.uid == myUid && c.isActiveAt(now)) c,
  ];

  /// 같은 장소의 다른 사람 카드(차단·체크아웃 제외)
  List<Checkin> feed(String spotId, DateTime now) => [
    for (final c in checkins)
      if (c.spotId == spotId &&
          c.uid != myUid &&
          c.isActiveAt(now) &&
          !isBlocked(c.uid))
        c,
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  /// 스팟에 지금 있는 사람 수(나 포함)
  int headcount(String spotId, DateTime now) {
    // 실제 모드에서 지켜보지 않는 장소는 서버가 센 인원(activeCount)을 쓴다.
    final counted = spot(spotId)?.activeCount;
    if (counted != null && spotId != liveSpotId) return counted;
    return {
      for (final c in checkins)
        if (c.spotId == spotId && c.isActiveAt(now)) c.uid,
    }.length;
  }

  List<ChatRequest> received() => [
    for (final r in requests)
      if (r.toUid == myUid && !isBlocked(r.fromUid)) r,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ChatRequest> sent() => [
    for (final r in requests)
      if (r.fromUid == myUid) r,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get pendingReceivedCount =>
      received().where((r) => r.status == ChatRequestStatus.pending).length;

  ChatRequest? request(String id) =>
      requests.where((r) => r.id == id).firstOrNull;

  ChatRequest? pendingTo(String uid) => requests
      .where(
        (r) =>
            r.fromUid == myUid &&
            r.toUid == uid &&
            r.status == ChatRequestStatus.pending,
      )
      .firstOrNull;

  int sentToday(DateTime now) => requests
      .where(
        (r) =>
            r.fromUid == myUid &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month &&
            r.createdAt.day == now.day,
      )
      .length;

  /// 내가 들어 있는 대화, 최근 메시지순(US-012). 보관 기간 제한은 없다.
  /// 1:1은 상대를 차단하면 숨긴다. 그룹은 남기고 차단한 사람의 메시지만 숨긴다.
  List<Chat> visibleChats(DateTime now) =>
      [
        for (final c in chats)
          if (c.memberUids.contains(myUid) &&
              (c.isGroup || !isBlocked(c.otherUid(myUid))))
            c,
      ]..sort(
        (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
          a.lastMessageAt ?? a.createdAt,
        ),
      );

  Chat? chat(String id) => chats.where((c) => c.id == id).firstOrNull;

  /// 이 사람과 열려 있는 1:1 대화방(보관 기간 안)
  Chat? chatWith(String uid, DateTime now) => visibleChats(now)
      .where(
        (c) =>
            !c.isGroup && c.otherUid(myUid) == uid && !c.leftUids.contains(uid),
      )
      .firstOrNull;

  int unreadTotal(DateTime now) =>
      visibleChats(now).fold(0, (sum, c) => sum + (unread[c.id] ?? 0));

  bool get isPlusActive {
    final until = me?.plusExpiresAt;
    return (me?.isPlus ?? false) &&
        until != null &&
        until.isAfter(DateTime.now());
  }

  int get topicLimit =>
      isPlusActive ? AppLimits.plusActiveTopics : AppLimits.freeActiveTopics;

  Checkin? checkin(String id) => checkins.where((c) => c.id == id).firstOrNull;
}

enum SendRequestResult { sent, duplicate, dailyLimit, notCheckedIn }

/// 그룹 채팅 참여 결과(US-025)
enum GroupJoinResult {
  joined,

  /// 최대 인원([AppLimits.groupChatMaxMembers])이 찼다
  full,

  /// 나도 같은 장소에 체크인해 있어야 한다
  notCheckedIn,

  /// 카드가 내려갔거나 볼 수 없는 방
  gone,
}

class DemoStore extends Notifier<DemoDb> {
  final _timers = <Timer>[];
  int _replyCursor = 0;

  @override
  DemoDb build() {
    ref.onDispose(() {
      for (final t in _timers) {
        t.cancel();
      }
      _timers.clear();
    });
    _timers.add(Timer.periodic(const Duration(seconds: 15), (_) => _tick()));
    return ref.read(liveModeProvider)
        ? DemoDb._empty()
        : DemoDb._seed(DateTime.now());
  }

  DemoDb get _db => state;

  /// 실제(Firebase) 모드. 바꾼 내용을 화면에 먼저 반영하고 Firestore에도 쓴다.
  /// 더미 시나리오(상대 수락·도착 등)는 돌리지 않는다.
  bool get _live => ref.read(liveModeProvider);

  /// 실제 모드에서만 Firestore에 쓴다. 실패하면 알리고 [onFail]로 되돌린다.
  void _remote(
    Future<void> Function(CheckinRepository repo, String uid) write, {
    void Function()? onFail,
  }) {
    if (!_live) return;
    final uid = ref.read(sessionProvider).uid;
    if (uid == null) return;
    write(ref.read(checkinRepositoryProvider), uid).catchError((Object e) {
      debugPrint('[BIND] 저장 실패: $e');
      _notice('저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
      onFail?.call();
    });
  }

  /// 실제 모드에서만 서버에 쓴다(차단·신고·평가 등). 실패하면 알린다.
  void _liveWrite(Future<void> Function(String uid) write) {
    if (!_live) return;
    final uid = ref.read(sessionProvider).uid;
    if (uid == null) return;
    write(uid).catchError((Object e) {
      debugPrint('[BIND] 저장 실패: $e');
      _notice('저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
    });
  }

  /// 프로필을 아직 못 읽어 온 상대도 카드·요청에 있는 닉네임으로 찾는다.
  String _nicknameOf(String uid) =>
      _db.user(uid)?.nickname ??
      _db.checkins.where((c) => c.uid == uid).firstOrNull?.nickname ??
      _db.requests.where((r) => r.fromUid == uid).firstOrNull?.fromNickname ??
      '알 수 없음';

  /// 차단 목록(실제 모드: 서버 목록으로 통째로 바꾼다)
  void applyBlocks(List<Block> blocks) {
    _db.blocks
      ..clear()
      ..addAll({for (final b in blocks) b.targetUid: b});
    _commit({DemoPart.blocks});
  }

  /// 내 프로필이 서버에서 바뀌었을 때(좋았어요 수·BIND+·정지)
  void applyMe(AppUser profile) {
    if (_db.me == null) return;
    enter(profile);
    if (profile.suspended) _session.suspend();
  }

  /// 내 체크인 중 서버에 저장된 것(서버 id)
  Iterable<String> get _myRemoteIds => [
    for (final c in _db.myCheckins(_now))
      if (!c.id.startsWith('my-checkin')) c.id,
  ];

  // ── 실제 모드: Firestore 실시간 데이터 반영(LiveSync가 부른다) ──

  /// 내 체크아웃 전 카드. 서버 목록으로 통째로 바꾼다.
  void applyMyCheckins(List<Checkin> mine) {
    _db.checkins
      ..removeWhere((c) => c.uid == DemoDb.myUid)
      ..addAll(mine);
    _commit({DemoPart.checkins});
    final first = mine.firstOrNull;
    final session = ref.read(sessionProvider);
    if (first == null) {
      if (session.isCheckedIn) _session.checkedOut();
    } else if (session.activeCheckinId != first.id) {
      _session.checkedIn(checkinId: first.id, spotId: first.spotId);
    }
  }

  /// 지켜보는 장소의 다른 사람 카드. null이면 지켜보기를 끝낸다.
  void applySpotCheckins(String? spotId, List<Checkin> cards) {
    final previous = _db.liveSpotId;
    _db.liveSpotId = spotId;
    _db.checkins.removeWhere(
      (c) =>
          c.uid != DemoDb.myUid && (c.spotId == spotId || c.spotId == previous),
    );
    _db.checkins.addAll([
      for (final c in cards)
        if (c.uid != DemoDb.myUid) c,
    ]);
    _commit({DemoPart.checkins});
  }

  /// 장소 정보(이름·인원)를 넣거나 바꾼다.
  void applySpots(List<Spot> spots) {
    if (spots.isEmpty) return;
    for (final s in spots) {
      final i = _db.spots.indexWhere((x) => x.id == s.id);
      if (i < 0) {
        _db.spots.add(s);
      } else {
        _db.spots[i] = s;
      }
    }
    _commit({DemoPart.places, DemoPart.checkins});
  }

  /// 받은 요청(서버 목록으로 통째로 바꾼다)
  void applyReceivedRequests(List<ChatRequest> received) {
    _db.requests
      ..removeWhere((r) => r.toUid == DemoDb.myUid)
      ..addAll(received);
    _commit({DemoPart.requests});
  }

  /// 보낸 요청. 서버 응답 전에 화면에 먼저 넣어 둔 요청(req-out-)은 지운다.
  void applySentRequests(List<ChatRequest> sent) {
    _db.requests
      ..removeWhere((r) => r.fromUid == DemoDb.myUid)
      ..addAll(sent);
    _commit({DemoPart.requests});
  }

  /// 채팅방 목록 + 방마다 내 안 읽은 수
  void applyChats(List<(Chat, int)> chats) {
    _db.chats
      ..clear()
      ..addAll([for (final (c, _) in chats) c]);
    _db.unread
      ..clear()
      ..addAll({for (final (c, n) in chats) c.id: n});
    _commit({DemoPart.chats});
  }

  /// 상대 프로필(닉네임·하는 일·좋았어요 수)
  void applyUsers(List<AppUser> users) {
    if (users.isEmpty) return;
    for (final u in users) {
      _db.users[u.uid] = u;
    }
    _commit({DemoPart.profile, DemoPart.chats});
  }

  /// 로그아웃·탈퇴: 실제 모드 데이터를 비운다.
  void clearLive() {
    if (!_live) return;
    state = DemoDb._empty();
  }

  DateTime get _now => DateTime.now();
  SessionController get _session => ref.read(sessionProvider.notifier);

  /// 바뀐 묶음의 버전을 올리고 알린다. 각 파생 provider는 자기 묶음 버전만 본다.
  void _commit(Set<DemoPart> parts, {String? chatId}) {
    _db.rev.bump(parts, chatId: chatId);
    ref.notifyListeners();
  }

  void _notice(String message, {String? actionLabel, String? route}) => ref
      .read(inAppNoticeProvider.notifier)
      .show(InAppNotice(message, actionLabel: actionLabel, route: route));

  void _later(Duration delay, void Function() action) {
    late final Timer t;
    t = Timer(delay, () {
      _timers.remove(t);
      action();
    });
    _timers.add(t);
  }

  /// 15초마다: 요청 만료(30분) 처리.
  /// 실제 서비스에서는 Cloud Functions 스케줄러가 한다.
  void _tick() {
    final now = _now;
    var changed = false;
    for (final (i, r) in _db.requests.indexed.toList()) {
      if (r.status == ChatRequestStatus.pending && now.isAfter(r.expiresAt)) {
        changed = true;
        _db.requests[i] = r.copyWith(status: ChatRequestStatus.expired);
        if (r.fromUid == DemoDb.myUid) {
          _notice(
            '${_db.user(r.toUid)?.nickname}님이 답하지 않아 요청이 끝났어요',
            actionLabel: '보기',
            route: Routes.requestsSent,
          );
        }
      }
    }
    // 남은 시간 표시는 clockProvider가 맡으므로, 실제로 바뀐 게 있을 때만 알린다.
    if (changed) _commit({DemoPart.requests});
  }

  // ── 인증·온보딩 ─────────────────────────────────────

  void signIn() =>
      _session.signedIn(uid: DemoDb.myUid, isOnboarded: _db.me != null);

  void signOut() {
    // US-001: 가입 도중 취소하면 입력한 정보를 남기지 않는다.
    if (_db.me == null) {
      _db
        ..draftNickname = null
        ..draftJobTag = null
        ..draftJobCustom = null;
      _commit({DemoPart.profile});
    }
    _session.signOut();
  }

  /// 서버에서 불러온 내 프로필로 바꾼다(Firebase 모드). null이면 온보딩 전.
  /// 데모 데이터 안에서는 내 uid를 [DemoDb.myUid]로 통일해 쓴다.
  void enter(AppUser? profile) {
    _db.me = profile == null
        ? null
        : AppUser(
            uid: DemoDb.myUid,
            nickname: profile.nickname,
            jobTag: profile.jobTag,
            jobCustom: profile.jobCustom,
            consentedAt: profile.consentedAt,
            goodReviewCount: profile.goodReviewCount,
            isPlus: profile.isPlus,
            plusExpiresAt: profile.plusExpiresAt,
            suspended: profile.suspended,
            onboardingGuideSeen: profile.onboardingGuideSeen,
            ageBand: profile.ageBand,
            gender: profile.gender,
          );
    _commit({DemoPart.profile});
  }

  /// 온보딩 1단계에서 입력한 값으로 만든 프로필(서버 저장용, 실제 uid)
  AppUser draftUser(String uid) => AppUser(
    uid: uid,
    nickname: _db.draftNickname ?? '',
    jobTag: _db.draftJobTag ?? JobTag.other,
    jobCustom: _db.draftJobCustom,
    consentedAt: _now,
  );

  bool isNicknameTaken(String nickname) {
    final n = nickname.trim();
    return _db.users.values.any((u) => !u.deleted && u.nickname == n);
  }

  void saveDraftProfile(String nickname, JobTag jobTag, {String? jobCustom}) {
    _db
      ..draftNickname = nickname.trim()
      ..draftJobTag = jobTag
      ..draftJobCustom = jobTag == JobTag.other ? jobCustom?.trim() : null;
    _commit({DemoPart.profile});
  }

  void completeOnboarding() {
    _db.me = AppUser(
      uid: DemoDb.myUid,
      nickname: _db.draftNickname ?? '',
      jobTag: _db.draftJobTag ?? JobTag.other,
      jobCustom: _db.draftJobCustom,
      consentedAt: _now,
    );
    _commit({DemoPart.profile});
    _session.completeOnboarding();
  }

  void markGuideSeen() {
    _db.me = _db.me?.copyWith(onboardingGuideSeen: true);
    _commit({DemoPart.profile});
  }

  void updateProfile(String nickname, JobTag jobTag, {String? jobCustom}) {
    _db.me = _db.me?.copyWith(
      nickname: nickname.trim(),
      jobTag: jobTag,
      jobCustom: () => jobTag == JobTag.other ? jobCustom?.trim() : null,
    );
    for (final (i, c) in _db.checkins.indexed.toList()) {
      if (c.uid == DemoDb.myUid) {
        _db.checkins[i] = _withProfile(c, _db.me!);
      }
    }
    _commit({DemoPart.profile, DemoPart.checkins});
    final me = _db.me;
    if (me != null) {
      final ids = _myRemoteIds.toList();
      if (ids.isNotEmpty) {
        _remote((repo, _) => repo.updateCardsProfile(ids, me));
      }
    }
  }

  Checkin _withProfile(Checkin c, AppUser me) => Checkin(
    id: c.id,
    uid: c.uid,
    spotId: c.spotId,
    nickname: me.nickname,
    jobTag: me.jobTag,
    jobCustom: me.jobCustom,
    topic: c.topic,
    category: c.category,
    startedAt: c.startedAt,
    checkedOutAt: c.checkedOutAt,
    hasTrustBadge: me.hasTrustBadge,
    notifyWhenSomeoneArrives: c.notifyWhenSomeoneArrives,
    openGroupChat: c.openGroupChat,
    groupChatId: c.groupChatId,
    groupMemberCount: c.groupMemberCount,
    ageBand: c.ageBand,
    gender: c.gender,
  );

  /// 탈퇴: 데모 데이터를 처음 상태로 되돌리고 로그아웃한다.
  void deleteAccount() {
    for (final t in _timers.skip(1)) {
      t.cancel();
    }
    _timers.removeRange(1, _timers.length);
    state = _live ? DemoDb._empty() : DemoDb._seed(_now);
    _session.signOut();
  }

  /// 데모 확인용: 신고 누적 정지 상태 보기
  void previewSuspension() => _session.suspend();

  // ── 체크인 ──────────────────────────────────────────

  /// 검색해서 고른 장소로 체크인한다. 같은 카카오 장소가 열려 있으면 거기로, 없으면 새로 연다.
  /// 실제 모드: spots/{placeId} 찾기·만들기 + checkins 문서 생성(한 트랜잭션)
  ///
  /// [openGroupChat]을 켜면 이 카드로 그룹 채팅도 연다(US-025).
  /// 실제 모드는 서버(onCheckinWritten)가 방을 만들고 카드에 groupChatId를 적는다.
  ///
  /// [ageBand]·[gender]는 필수로 카드에 보이고, 프로필에 남겨 다음 체크인에 미리 채운다.
  void checkIn({
    required Place place,
    required String topic,
    required TopicCategory category,
    required AgeBand ageBand,
    required Gender gender,
    String? categoryCustom,
    bool openGroupChat = false,
  }) {
    final custom = _customFor(category, categoryCustom);
    final me = _db.me!.copyWith(ageBand: ageBand, gender: gender);
    _db.me = me;
    final now = _now;
    final spot = _db.spotByPlaceId(place.id) ?? _openSpot(place, now);
    final checkinId = _db.nextId('my-checkin');
    // 데모: 서버 대신 그룹 채팅방을 바로 만든다.
    final groupChatId = openGroupChat && !_live
        ? _openGroupChatLocal(checkinId, topic.trim(), now)
        : null;
    final checkin = Checkin(
      id: checkinId,
      uid: DemoDb.myUid,
      spotId: spot.id,
      nickname: me.nickname,
      jobTag: me.jobTag,
      jobCustom: me.jobCustom,
      topic: topic.trim(),
      category: category,
      categoryCustom: custom,
      startedAt: now,
      hasTrustBadge: me.hasTrustBadge,
      openGroupChat: openGroupChat,
      groupChatId: groupChatId,
      groupMemberCount: groupChatId == null ? 0 : 1,
      ageBand: ageBand,
      gender: gender,
    );
    _db.checkins.add(checkin);
    _rememberTopic(topic.trim(), category);
    _db.recentSpotIds
      ..remove(spot.id)
      ..insert(0, spot.id);
    if (_db.recentSpotIds.length > AppLimits.recentPlacesCount) {
      _db.recentSpotIds.removeLast();
    }
    _commit({
      DemoPart.profile,
      DemoPart.checkins,
      DemoPart.places,
      DemoPart.topics,
      if (groupChatId != null) DemoPart.chats,
    });
    _session.checkedIn(checkinId: checkin.id, spotId: spot.id);
    if (_live) {
      _remote(
        (repo, uid) => repo.checkIn(
          uid: uid,
          me: me,
          place: place,
          topic: topic.trim(),
          category: category,
          categoryCustom: custom,
          openGroupChat: openGroupChat,
        ),
        onFail: () => _checkOutLocal(checkin.id),
      );
    } else {
      _scheduleIncoming(checkin);
      if (groupChatId != null) _scheduleGroupJoiners(checkin);
    }
  }

  /// 데모: 내 카드로 그룹 채팅방을 연다(나 혼자 시작). 방 id를 돌려준다.
  String _openGroupChatLocal(String checkinId, String topic, DateTime now) {
    final id = _db.nextId('group');
    _db.chats.add(
      Chat(
        id: id,
        type: ChatType.group,
        title: topic,
        ownerUid: DemoDb.myUid,
        checkinId: checkinId,
        memberUids: const [DemoDb.myUid],
        createdAt: now,
      ),
    );
    _db.messages[id] = [];
    _db.unread[id] = 0;
    return id;
  }

  /// 데모: 내가 연 그룹 채팅에 같은 장소 사람이 몇 초 뒤 들어와 인사한다.
  void _scheduleGroupJoiners(Checkin mine) {
    final chatId = mine.groupChatId!;
    for (final (uid, text, delay) in DemoSeed.groupJoiners) {
      if (!_db.feed(mine.spotId, _now).any((c) => c.uid == uid)) continue;
      _later(delay, () {
        final card = _db.checkin(mine.id);
        final chat = _db.chat(chatId);
        if (card == null ||
            !card.isActiveAt(_now) ||
            chat == null ||
            _db.isBlocked(uid) ||
            chat.memberUids.contains(uid) ||
            chat.activeMemberCount >= AppLimits.groupChatMaxMembers) {
          return;
        }
        _addGroupMember(chatId, uid);
        _partnerSays(chatId, text, from: uid);
        _notice(
          '${_nicknameOf(uid)}님이 그룹 채팅에 들어왔어요',
          actionLabel: '보기',
          route: Routes.chatRoom(chatId),
        );
      });
    }
  }

  /// 그룹 채팅방에 [uid]를 넣고, 방을 연 카드의 인원 수를 맞춘다.
  /// 데모는 "○○님이 입장했습니다" 안내도 넣는다(실제 모드는 서버 joinGroupChat이 쓴다).
  void _addGroupMember(String chatId, String uid) {
    final i = _db.chats.indexWhere((c) => c.id == chatId);
    if (i < 0) return;
    final chat = _db.chats[i];
    if (chat.memberUids.contains(uid)) return;
    _db.chats[i] = chat.copyWith(memberUids: [...chat.memberUids, uid]);
    _syncGroupCount(_db.chats[i]);
    if (!_live) _appendNotice(chatId, uid, MessageKind.join);
    _commit({DemoPart.chats, DemoPart.checkins});
  }

  /// 그룹 채팅 입장·퇴장 안내. 안 읽은 수·메시지 수에는 넣지 않고 목록 미리보기만 바꾼다.
  void _appendNotice(String chatId, String uid, MessageKind kind) {
    final now = _now;
    final text = ChatMessage.noticeText(kind, _nicknameOf(uid));
    _db.messages
        .putIfAbsent(chatId, () => [])
        .add(
          ChatMessage(
            id: _db.nextId('notice'),
            senderUid: uid,
            text: text,
            sentAt: now,
            kind: kind,
          ),
        );
    final i = _db.chats.indexWhere((c) => c.id == chatId);
    if (i >= 0) {
      _db.chats[i] = _db.chats[i].copyWith(lastMessage: text, lastMessageAt: now);
    }
    _commit({DemoPart.chats}, chatId: chatId);
  }

  /// 방을 연 카드에 적힌 인원 수(피드에서 보이는 값)를 방과 맞춘다.
  void _syncGroupCount(Chat chat) {
    final i = _db.checkins.indexWhere((c) => c.groupChatId == chat.id);
    if (i < 0) return;
    _db.checkins[i] = _db.checkins[i].copyWith(
      groupMemberCount: chat.activeMemberCount,
    );
  }

  /// 서버 저장에 실패한 카드를 화면에서 내린다.
  void _checkOutLocal(String checkinId) {
    final i = _db.checkins.indexWhere((c) => c.id == checkinId);
    if (i < 0) return;
    _db.checkins[i] = _db.checkins[i].copyWith(checkedOutAt: _now);
    _commit({DemoPart.checkins});
    if (_db.myCheckins(_now).isEmpty) _session.checkedOut();
  }

  Spot _openSpot(Place place, DateTime now) {
    // 장소 id = 카카오 장소 ID(실제 모드의 Firestore 문서 id와 같다)
    final spot = Spot(
      id: place.id,
      placeId: place.id,
      name: place.name,
      address: place.address,
      category: place.category,
      creatorUid: DemoDb.myUid,
      createdAt: now,
    );
    _db.spots.add(spot);
    return spot;
  }

  void addTopic(
    String topic,
    TopicCategory category, {
    String? categoryCustom,
  }) {
    final custom = _customFor(category, categoryCustom);
    final first = _db.myCheckins(_now).first;
    final me = _db.me!;
    _db.checkins.add(
      Checkin(
        id: _db.nextId('my-checkin'),
        uid: DemoDb.myUid,
        spotId: first.spotId,
        nickname: me.nickname,
        jobTag: me.jobTag,
        jobCustom: me.jobCustom,
        topic: topic.trim(),
        category: category,
        categoryCustom: custom,
        startedAt: _now,
        hasTrustBadge: me.hasTrustBadge,
        // 같은 체크인의 주제라 처음 고른 연령대·성별을 그대로 쓴다.
        ageBand: first.ageBand,
        gender: first.gender,
      ),
    );
    _rememberTopic(topic.trim(), category);
    _commit({DemoPart.checkins, DemoPart.topics});
    _remote(
      (repo, uid) => repo.addTopic(
        uid: uid,
        me: me,
        spotId: first.spotId,
        topic: topic.trim(),
        category: category,
        categoryCustom: custom,
      ),
    );
  }

  void updateTopic(
    String checkinId,
    String topic,
    TopicCategory category, {
    String? categoryCustom,
  }) {
    final i = _db.checkins.indexWhere((c) => c.id == checkinId);
    if (i < 0) return;
    final custom = _customFor(category, categoryCustom);
    _db.checkins[i] = _db.checkins[i].copyWith(
      topic: topic.trim(),
      category: category,
      categoryCustom: () => custom,
    );
    _rememberTopic(topic.trim(), category);
    // 그룹 채팅 이름은 카드 주제를 따른다(실제 모드는 onCheckinWritten이 바꾼다).
    final groupId = _db.checkins[i].groupChatId;
    final g = groupId == null
        ? -1
        : _db.chats.indexWhere((c) => c.id == groupId);
    if (g >= 0) _db.chats[g] = _db.chats[g].copyWith(title: topic.trim());
    _commit({DemoPart.checkins, DemoPart.topics, if (g >= 0) DemoPart.chats});
    _remote(
      (repo, _) => repo.updateTopic(
        checkinId,
        topic.trim(),
        category,
        categoryCustom: custom,
      ),
    );
  }

  void removeTopic(String checkinId) {
    final i = _db.checkins.indexWhere((c) => c.id == checkinId);
    if (i < 0) return;
    _db.checkins[i] = _db.checkins[i].copyWith(checkedOutAt: _now);
    _commit({DemoPart.checkins});
    _remote((repo, _) => repo.checkOutOne(checkinId));
  }

  /// 기타일 때만 직접 입력한 키워드를 남긴다.
  static String? _customFor(TopicCategory category, String? custom) =>
      category == TopicCategory.other && (custom?.trim().isNotEmpty ?? false)
      ? custom!.trim()
      : null;

  void _rememberTopic(String topic, TopicCategory category) {
    _db.recentTopics
      ..removeWhere((t) => t.$1 == topic)
      ..insert(0, (topic, category));
    if (_db.recentTopics.length > AppLimits.recentTopicsCount) {
      _db.recentTopics.removeRange(
        AppLimits.recentTopicsCount,
        _db.recentTopics.length,
      );
    }
  }

  void deleteRecentTopic(String topic) {
    _db.recentTopics.removeWhere((t) => t.$1 == topic);
    _commit({DemoPart.topics});
  }

  void checkOut() {
    final ids = _myRemoteIds.toList();
    _checkOutAll(_now);
    _commit({DemoPart.checkins});
    _remote((repo, _) => repo.checkOutAll(ids));
  }

  void _checkOutAll(DateTime now) {
    for (final (i, c) in _db.checkins.indexed.toList()) {
      if (c.uid == DemoDb.myUid && c.checkedOutAt == null) {
        _db.checkins[i] = c.copyWith(
          checkedOutAt: now,
          notifyWhenSomeoneArrives: false,
        );
      }
    }
    _session.checkedOut();
  }

  /// US-015 빈 스팟 "누가 오면 알려줘"
  void setArrivalNotify(bool on) {
    final now = _now;
    final mine = _db.myCheckins(now);
    if (mine.isEmpty) return;
    for (final c in mine) {
      final i = _db.checkins.indexOf(c);
      _db.checkins[i] = c.copyWith(notifyWhenSomeoneArrives: on);
    }
    _commit({DemoPart.checkins});
    if (_live) {
      // TODO(fcm): 첫 사람이 체크인하면 Functions가 푸시로 알린다.
      final ids = _myRemoteIds.toList();
      _remote((repo, _) => repo.setArrivalNotify(ids, on));
      return;
    }
    if (!on) return;

    final spotId = mine.first.spotId;
    _later(DemoSeed.arrivalDelay, () {
      final still = _db.myCheckins(_now);
      if (still.isEmpty || !still.first.notifyWhenSomeoneArrives) return;
      final u = _db.users[DemoSeed.arrivingUid]!;
      final (topic, category) = DemoSeed.arrivingTopic;
      final t = _now;
      _db.checkins.add(
        Checkin(
          id: _db.nextId('arrival'),
          uid: u.uid,
          spotId: spotId,
          nickname: u.nickname,
          jobTag: u.jobTag,
          topic: topic,
          category: category,
          startedAt: t,
          hasTrustBadge: u.hasTrustBadge,
          ageBand: u.ageBand,
          gender: u.gender,
        ),
      );
      // 알림은 1번만
      for (final c in still) {
        final i = _db.checkins.indexWhere((x) => x.id == c.id);
        _db.checkins[i] = _db.checkins[i].copyWith(
          notifyWhenSomeoneArrives: false,
        );
      }
      _commit({DemoPart.checkins});
      _notice(
        '${u.nickname}님이 체크인했어요: "$topic"',
        actionLabel: '보기',
        route: Routes.spot,
      );
    });
  }

  /// 체크인 직후 같은 스팟 사람이 나에게 요청을 보낸다(데모 시나리오).
  void _scheduleIncoming(Checkin mine) {
    final people = [
      for (final (uid, _, _) in DemoSeed.incomingRequests)
        if (_db.feed(mine.spotId, _now).any((c) => c.uid == uid)) uid,
    ];
    // 시나리오 인물이 없는 스팟이면 그 스팟의 다른 사람으로 대신한다.
    final fallback = _db
        .feed(mine.spotId, _now)
        .map((c) => c.uid)
        .where((u) => !people.contains(u))
        .toSet()
        .toList();
    for (final (i, (seedUid, message, delay))
        in DemoSeed.incomingRequests.indexed) {
      final uid = people.contains(seedUid)
          ? seedUid
          : (i < fallback.length ? fallback[i] : null);
      if (uid == null) continue;
      _later(delay, () {
        final active = _db.myCheckins(_now);
        // 이미 대화 중이거나 내가 먼저 요청한 사람이면 보내지 않는다.
        if (active.isEmpty ||
            _db.isBlocked(uid) ||
            _db.chatWith(uid, _now) != null ||
            _db.pendingTo(uid) != null) {
          return;
        }
        final from = _db.users[uid]!;
        final t = _now;
        final req = ChatRequest(
          id: _db.nextId('req-in'),
          fromUid: uid,
          toUid: DemoDb.myUid,
          spotId: mine.spotId,
          toCheckinId: active.first.id,
          message: message,
          status: ChatRequestStatus.pending,
          createdAt: t,
          expiresAt: t.add(AppLimits.requestExpiry),
          fromNickname: from.nickname,
          fromJobTag: from.jobTag,
        );
        _db.requests.add(req);
        _commit({DemoPart.requests});
        _notice(
          '${from.nickname}님이 대화를 요청했어요',
          actionLabel: '보기',
          route: Routes.requestDetail(req.id),
        );
      });
    }
  }

  // ── 요청 ────────────────────────────────────────────

  /// 화면에서 부르는 요청 보내기. 실제 모드는 서버(sendRequest)가 최종 판단한다.
  Future<SendRequestResult> requestChat(Checkin target, String message) async {
    if (!_live) return sendRequest(target, message);
    // 화면에 있는 값으로 먼저 걸러내고(빠른 안내), 서버가 다시 확인한다.
    final now = _now;
    if (_db.myCheckins(now).isEmpty) return SendRequestResult.notCheckedIn;
    if (_db.pendingTo(target.uid) != null) return SendRequestResult.duplicate;
    if (!_db.isPlusActive &&
        _db.sentToday(now) >= AppLimits.freeDailyRequests) {
      return SendRequestResult.dailyLimit;
    }
    final result = await ref
        .read(requestRepositoryProvider)
        .send(toCheckinId: target.id, message: message.trim());
    return switch (result) {
      RemoteSendResult.sent => SendRequestResult.sent,
      RemoteSendResult.duplicate => SendRequestResult.duplicate,
      RemoteSendResult.dailyLimit => SendRequestResult.dailyLimit,
      RemoteSendResult.notCheckedIn ||
      RemoteSendResult.gone => SendRequestResult.notCheckedIn,
    };
  }

  /// 화면에서 부르는 수락·거절. 수락하면 채팅방 id.
  /// 실제 모드는 서버(respondRequest)가 채팅방을 만든다.
  Future<String?> respondTo(String requestId, {required bool accept}) async {
    if (!_live) return respond(requestId, accept: accept);
    final r = _db.request(requestId);
    if (r == null) return null;
    final chatId = await ref
        .read(requestRepositoryProvider)
        .respond(requestId, accept: accept);
    // 서버 목록이 오기 전에 화면에 먼저 반영한다(바로 대화방으로 들어가도록).
    final i = _db.requests.indexWhere((x) => x.id == requestId);
    if (i >= 0) {
      _db.requests[i] = r.copyWith(
        status: chatId != null
            ? ChatRequestStatus.accepted
            : (accept ? ChatRequestStatus.expired : ChatRequestStatus.rejected),
        chatId: chatId,
      );
    }
    if (chatId != null && _db.chat(chatId) == null) {
      final now = _now;
      _db.chats.add(
        Chat(
          id: chatId,
          memberUids: [r.fromUid, DemoDb.myUid],
          createdAt: now,
          lastMessage: r.message,
          lastMessageAt: now,
        ),
      );
      _db.messages[chatId] = [
        ChatMessage(
          id: 'first-$chatId',
          senderUid: r.fromUid,
          text: r.message,
          sentAt: r.createdAt,
        ),
      ];
      _db.unread[chatId] = 0;
    }
    _commit({DemoPart.requests, DemoPart.chats});
    return chatId;
  }

  SendRequestResult sendRequest(Checkin target, String message) {
    final now = _now;
    final mine = _db.myCheckins(now);
    if (mine.isEmpty) return SendRequestResult.notCheckedIn;
    if (_db.pendingTo(target.uid) != null) return SendRequestResult.duplicate;
    if (!_db.isPlusActive &&
        _db.sentToday(now) >= AppLimits.freeDailyRequests) {
      return SendRequestResult.dailyLimit;
    }
    final me = _db.me!;
    final req = ChatRequest(
      id: _db.nextId('req-out'),
      fromUid: DemoDb.myUid,
      toUid: target.uid,
      spotId: target.spotId,
      toCheckinId: target.id,
      message: message.trim(),
      status: ChatRequestStatus.pending,
      createdAt: now,
      expiresAt: now.add(AppLimits.requestExpiry),
      fromNickname: me.nickname,
      fromJobTag: me.jobTag,
      fromJobCustom: me.jobCustom,
    );
    _db.requests.add(req);
    _commit({DemoPart.requests});

    _later(DemoSeed.responseDelay, () {
      final current = _db.request(req.id);
      if (current == null || current.status != ChatRequestStatus.pending) {
        return;
      }
      final other = _db.users[target.uid]!;
      final i = _db.requests.indexOf(current);
      if (DemoSeed.rejectingUids.contains(target.uid)) {
        _db.requests[i] = current.copyWith(status: ChatRequestStatus.rejected);
        _commit({DemoPart.requests});
        _notice(
          '${other.nickname}님은 이번엔 어렵대요',
          actionLabel: '보기',
          route: Routes.requestsSent,
        );
        return;
      }
      final chatId = _createChat(target.uid, firstMessage: null);
      _db.requests[i] = current.copyWith(
        status: ChatRequestStatus.accepted,
        chatId: chatId,
      );
      _commit({DemoPart.requests, DemoPart.chats});
      _notice(
        '${other.nickname}님이 대화 요청을 수락했어요',
        actionLabel: '대화하기',
        route: Routes.chatRoom(chatId),
      );
      _later(
        DemoSeed.replyDelay,
        () => _partnerSays(chatId, DemoSeed.greeting),
      );
    });
    return SendRequestResult.sent;
  }

  /// 받은 요청 수락 → 채팅방 id, 거절 → null
  String? respond(String requestId, {required bool accept}) {
    final r = _db.request(requestId);
    if (r == null || r.status != ChatRequestStatus.pending) return r?.chatId;
    final i = _db.requests.indexOf(r);
    if (!accept) {
      _db.requests[i] = r.copyWith(status: ChatRequestStatus.rejected);
      _commit({DemoPart.requests});
      return null;
    }
    final chatId =
        _db.chatWith(r.fromUid, _now)?.id ??
        _createChat(r.fromUid, firstMessage: r.message);
    _db.requests[i] = r.copyWith(
      status: ChatRequestStatus.accepted,
      chatId: chatId,
    );
    _commit({DemoPart.requests, DemoPart.chats});
    return chatId;
  }

  String _createChat(String otherUid, {required String? firstMessage}) {
    final now = _now;
    final id = _db.nextId('chat');
    _db.chats.add(
      Chat(
        id: id,
        memberUids: [DemoDb.myUid, otherUid],
        createdAt: now,
        lastMessage: firstMessage,
        lastMessageAt: now,
      ),
    );
    _db.messages[id] = [
      if (firstMessage != null)
        ChatMessage(
          id: _db.nextId('m'),
          senderUid: otherUid,
          text: firstMessage,
          sentAt: now,
        ),
    ];
    _db.unread[id] = 0;
    return id;
  }

  // ── 채팅 ────────────────────────────────────────────

  void openChat(String chatId) {
    if ((_db.unread[chatId] ?? 0) == 0) return;
    _db.unread[chatId] = 0;
    _commit({DemoPart.chats});
    if (_live) {
      final uid = ref.read(sessionProvider).uid;
      if (uid != null) {
        ref
            .read(requestRepositoryProvider)
            .markRead(chatId, uid)
            .catchError((Object e) => debugPrint('[BIND] 읽음 처리 실패: $e'));
      }
    }
  }

  /// 대화방 메시지(실제 모드: 서버 목록으로 통째로 바꾼다)
  void applyMessages(String chatId, List<ChatMessage> messages) {
    _db.messages[chatId] = messages;
    _commit({DemoPart.chats}, chatId: chatId);
  }

  void sendMessage(String chatId, String text) {
    final chat = _db.chat(chatId);
    if (chat == null || text.trim().isEmpty) return;
    _append(chatId, DemoDb.myUid, text.trim());
    if (_live) {
      final uid = ref.read(sessionProvider).uid;
      if (uid == null) return;
      ref
          .read(requestRepositoryProvider)
          .sendMessage(chatId: chatId, uid: uid, text: text.trim())
          .catchError((Object e) {
            debugPrint('[BIND] 메시지 전송 실패: $e');
            _notice('메시지를 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
          });
      return;
    }
    final reply = DemoSeed.replies[_replyCursor % DemoSeed.replies.length];
    if (chat.isGroup) {
      // 그룹: 남아 있는 다른 사람이 돌아가며 답한다.
      final others = [
        for (final u in chat.memberUids)
          if (u != DemoDb.myUid &&
              !chat.leftUids.contains(u) &&
              !_db.isBlocked(u))
            u,
      ];
      if (others.isEmpty) return;
      final from = others[_replyCursor++ % others.length];
      _later(
        DemoSeed.replyDelay,
        () => _partnerSays(chatId, reply, from: from),
      );
      return;
    }
    final other = chat.otherUid(DemoDb.myUid);
    if (chat.leftUids.contains(other)) return;
    _replyCursor++;
    _later(DemoSeed.replyDelay, () => _partnerSays(chatId, reply));
  }

  /// 데모 상대가 말한다. [from]이 없으면 1:1 상대.
  void _partnerSays(String chatId, String text, {String? from}) {
    final chat = _db.chat(chatId);
    if (chat == null) return;
    final other = from ?? chat.otherUid(DemoDb.myUid);
    if (_db.isBlocked(other) || !chat.memberUids.contains(other)) return;
    _append(chatId, other, text);
    _db.unread[chatId] = (_db.unread[chatId] ?? 0) + 1;
    _commit({DemoPart.chats}, chatId: chatId);
  }

  void _append(String chatId, String sender, String text) {
    final now = _now;
    _db.messages
        .putIfAbsent(chatId, () => [])
        .add(
          ChatMessage(
            id: _db.nextId('m'),
            senderUid: sender,
            text: text,
            sentAt: now,
          ),
        );
    final i = _db.chats.indexWhere((c) => c.id == chatId);
    final c = _db.chats[i];
    _db.chats[i] = c.copyWith(
      lastMessage: text,
      lastMessageAt: now,
      messageCounts: {
        ...c.messageCounts,
        sender: (c.messageCounts[sender] ?? 0) + 1,
      },
    );
    _commit({DemoPart.chats}, chatId: chatId);
  }

  /// 대화방을 나갈 때 평가를 물어볼지(한 번만, 양쪽 모두 말했을 때)
  bool shouldAskReview(String chatId) {
    if (_db.reviewAsked.contains(chatId)) return false;
    final chat = _db.chat(chatId);
    // 평가는 1:1 상대에게만(그룹 채팅은 묻지 않는다)
    if (chat == null || chat.isGroup) return false;
    final msgs = _db.messages[chatId] ?? const [];
    return msgs.any((m) => m.senderUid == DemoDb.myUid) &&
        msgs.any((m) => m.senderUid != DemoDb.myUid);
  }

  /// rating == null 이면 건너뛰기. 평가자는 상대에게 공개되지 않는다.
  void review(String chatId, ChatReviewRating? rating) {
    _db.reviewAsked.add(chatId);
    final chat = _db.chat(chatId);
    if (_live) {
      // 좋았어요 수는 서버(onReviewCreated)가 올린다.
      if (chat != null && rating != null) {
        final target = chat.otherUid(DemoDb.myUid);
        _liveWrite(
          (uid) => ref
              .read(safetyRepositoryProvider)
              .review(
                uid: uid,
                chatId: chatId,
                targetUid: target,
                rating: rating,
              ),
        );
      }
      _commit({DemoPart.chats});
      return;
    }
    if (chat != null && rating == ChatReviewRating.good) {
      final other = chat.otherUid(DemoDb.myUid);
      final u = _db.users[other];
      if (u != null) {
        _db.users[other] = u.copyWith(goodReviewCount: u.goodReviewCount + 1);
      }
    }
    _commit({DemoPart.chats});
  }

  // ── 그룹 채팅(US-025) ───────────────────────────────

  /// 카드에 열린 그룹 채팅에 들어간다. 들어가면 방 id도 돌려준다.
  /// 실제 모드는 서버(joinGroupChat)가 같은 장소·차단·인원을 다시 확인한다.
  Future<(GroupJoinResult, String?)> joinGroupChat(Checkin target) async {
    final now = _now;
    final chatId = target.groupChatId;
    if (_db.myCheckins(now).isEmpty) {
      return (GroupJoinResult.notCheckedIn, null);
    }
    if (chatId == null || _db.isBlocked(target.uid)) {
      return (GroupJoinResult.gone, null);
    }
    if (!_live) return _joinGroupLocal(target, chatId);

    final (remote, joinedId) = await ref
        .read(requestRepositoryProvider)
        .joinGroupChat(target.id);
    final result = switch (remote) {
      RemoteJoinResult.joined => GroupJoinResult.joined,
      RemoteJoinResult.full => GroupJoinResult.full,
      RemoteJoinResult.notCheckedIn => GroupJoinResult.notCheckedIn,
      RemoteJoinResult.gone => GroupJoinResult.gone,
    };
    if (result != GroupJoinResult.joined || joinedId == null) {
      return (result, null);
    }
    // 서버 목록이 오기 전에 화면에 먼저 넣는다(바로 대화방으로 들어가도록).
    final existing = _db.chat(joinedId);
    if (existing == null) {
      _db.chats.add(
        Chat(
          id: joinedId,
          type: ChatType.group,
          title: target.topic,
          ownerUid: target.uid,
          checkinId: target.id,
          memberUids: [target.uid, DemoDb.myUid],
          createdAt: now,
        ),
      );
      _db.unread[joinedId] = 0;
      _commit({DemoPart.chats});
    } else {
      _addGroupMember(joinedId, DemoDb.myUid);
    }
    return (GroupJoinResult.joined, joinedId);
  }

  (GroupJoinResult, String?) _joinGroupLocal(Checkin target, String chatId) {
    final chat = _db.chat(chatId);
    final card = _db.checkin(target.id);
    if (chat == null || card == null || !card.isActiveAt(_now)) {
      return (GroupJoinResult.gone, null);
    }
    if (chat.memberUids.contains(DemoDb.myUid)) {
      return (GroupJoinResult.joined, chatId);
    }
    if (chat.activeMemberCount >= AppLimits.groupChatMaxMembers) {
      return (GroupJoinResult.full, null);
    }
    _db.unread[chatId] = 0;
    _addGroupMember(chatId, DemoDb.myUid);
    final owner = chat.ownerUid;
    if (owner != null) {
      _later(
        DemoSeed.replyDelay,
        () => _partnerSays(chatId, DemoSeed.groupWelcome, from: owner),
      );
    }
    return (GroupJoinResult.joined, chatId);
  }

  /// 그룹 채팅에서 나간다. 방은 남은 사람끼리 이어진다.
  void leaveGroupChat(String chatId) {
    final i = _db.chats.indexWhere((c) => c.id == chatId);
    if (i < 0 || !_db.chats[i].isGroup) return;
    final chat = _db.chats[i];
    _db.chats[i] = chat.copyWith(
      memberUids: [
        for (final u in chat.memberUids)
          if (u != DemoDb.myUid) u,
      ],
    );
    _db.unread.remove(chatId);
    _syncGroupCount(_db.chats[i]);
    // 남은 사람에게 "○○님이 나갔습니다"(실제 모드는 서버 leaveGroupChat이 쓴다)
    if (!_live) _appendNotice(chatId, DemoDb.myUid, MessageKind.leave);
    _commit({DemoPart.chats, DemoPart.checkins});
    _liveWrite(
      (_) => ref.read(requestRepositoryProvider).leaveGroupChat(chatId),
    );
  }

  // ── 신고·차단 ───────────────────────────────────────

  void block(String uid) {
    final nickname = _nicknameOf(uid);
    _db.blocks[uid] = Block(
      targetUid: uid,
      targetNickname: nickname,
      createdAt: _now,
    );
    _commit({DemoPart.blocks});
    _liveWrite(
      (me) => ref.read(safetyRepositoryProvider).block(me, uid, nickname),
    );
  }

  void unblock(String uid) {
    _db.blocks.remove(uid);
    _commit({DemoPart.blocks});
    _liveWrite((me) => ref.read(safetyRepositoryProvider).unblock(me, uid));
  }

  /// 신고. 서로 다른 신고자가 쌓이면 서버(onReportCreated)가 정지한다.
  void report(
    String uid,
    ReportReason reason, {
    required bool alsoBlock,
    ReportSource source = ReportSource.feed,
  }) {
    _db.reportedUids.add(uid);
    _liveWrite(
      (me) => ref
          .read(safetyRepositoryProvider)
          .report(
            uid: me,
            targetUid: uid,
            reason: reason,
            source: source,
            alsoBlocked: alsoBlock,
          ),
    );
    if (alsoBlock) {
      block(uid);
    } else {
      _commit({DemoPart.blocks});
    }
  }

  // ── BIND+ ───────────────────────────────────────────

  void subscribePlus() {
    _db
      ..me = _db.me?.copyWith(
        isPlus: true,
        plusExpiresAt: () => _now.add(AppLimits.plusPeriod),
      )
      ..plusAutoRenew = true;
    _commit({DemoPart.profile});
  }

  /// 해지해도 결제한 기간까지는 혜택 유지(US-019)
  void cancelPlus() {
    _db.plusAutoRenew = false;
    _commit({DemoPart.profile});
  }
}

final demoStoreProvider = NotifierProvider<DemoStore, DemoDb>(DemoStore.new);
