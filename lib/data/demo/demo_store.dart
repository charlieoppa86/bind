import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/constants/app_limits.dart';
import '../../core/constants/enums.dart';
import '../../core/notice/in_app_notice.dart';
import '../../core/utils/korean_search.dart';
import '../../features/session/session.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../models/checkin.dart';
import '../models/safety.dart';
import '../models/spot.dart';
import 'demo_seed.dart';

/// 데모 모드 데이터 저장소(메모리).
///
/// Firebase 연결 전까지 Firestore 컬렉션(`spots`, `checkins`, `chatRequests`,
/// `chats`, `users/{uid}/blocks`)과 Cloud Functions가 하는 일
/// (코드 검증, 신청 만료, 채팅방 생성)을 흉내 낸다.
/// 상대방의 수락·답장·체크인은 [DemoSeed]의 시나리오대로 몇 초 뒤 일어난다.
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

  static const myUid = DemoSeed.myUid;

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

  /// 입력한 이름과 같은 장소(띄어쓰기·대소문자 무시)
  Spot? spotByName(String name) {
    final key = Spot.keyOf(name);
    return spots.where((s) => s.active && s.key == key).firstOrNull;
  }

  /// 장소 이름 자동완성: 이미 누군가 입력한 장소 중 비슷한 것, 사람 많은 순
  List<Spot> suggestSpots(String query, DateTime now) => [
    for (final s in spots)
      if (s.active && KoreanSearch.matches(s.name, query)) s,
  ]..sort((a, b) => headcount(b.id, now).compareTo(headcount(a.id, now)));

  /// 지금 사람이 있는 장소(사람 많은 순)
  List<Spot> activeSpots(DateTime now) => [
    for (final s in suggestSpots('', now))
      if (headcount(s.id, now) > 0) s,
  ];

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
  int headcount(String spotId, DateTime now) => {
    for (final c in checkins)
      if (c.spotId == spotId && c.isActiveAt(now)) c.uid,
  }.length;

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

  /// 7일이 지나지 않은 대화, 최근 메시지순(US-012)
  List<Chat> visibleChats(DateTime now) =>
      [
        for (final c in chats)
          if (c.expiresAt.isAfter(now) && !isBlocked(c.otherUid(myUid))) c,
      ]..sort(
        (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
          a.lastMessageAt ?? a.createdAt,
        ),
      );

  Chat? chat(String id) => chats.where((c) => c.id == id).firstOrNull;

  /// 이 사람과 열려 있는 대화방(보관 기간 안)
  Chat? chatWith(String uid, DateTime now) =>
      visibleChats(now)
          .where((c) => c.otherUid(myUid) == uid && !c.leftUids.contains(uid))
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
    return DemoDb._seed(DateTime.now());
  }

  DemoDb get _db => state;
  DateTime get _now => DateTime.now();
  SessionController get _session => ref.read(sessionProvider.notifier);

  void _commit() => ref.notifyListeners();

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

  /// 15초마다: 신청 만료(30분) 처리.
  /// 실제 서비스에서는 Cloud Functions 스케줄러가 한다.
  void _tick() {
    final now = _now;
    for (final (i, r) in _db.requests.indexed.toList()) {
      if (r.status == ChatRequestStatus.pending && now.isAfter(r.expiresAt)) {
        _db.requests[i] = r.copyWith(status: ChatRequestStatus.expired);
        if (r.fromUid == DemoDb.myUid) {
          _notice(
            '${_db.user(r.toUid)?.nickname}님이 답하지 않아 신청이 끝났어요',
            actionLabel: '보기',
            route: Routes.requestsSent,
          );
        }
      }
    }
    _commit();
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
      _commit();
    }
    _session.signOut();
  }

  bool isNicknameTaken(String nickname) {
    final n = nickname.trim();
    return _db.users.values.any((u) => !u.deleted && u.nickname == n);
  }

  void saveDraftProfile(String nickname, JobTag jobTag, {String? jobCustom}) {
    _db
      ..draftNickname = nickname.trim()
      ..draftJobTag = jobTag
      ..draftJobCustom = jobTag == JobTag.other ? jobCustom?.trim() : null;
    _commit();
  }

  void completeOnboarding() {
    _db.me = AppUser(
      uid: DemoDb.myUid,
      nickname: _db.draftNickname ?? '',
      jobTag: _db.draftJobTag ?? JobTag.other,
      jobCustom: _db.draftJobCustom,
      consentedAt: _now,
    );
    _commit();
    _session.completeOnboarding();
  }

  void markGuideSeen() {
    _db.me = _db.me?.copyWith(onboardingGuideSeen: true);
    _commit();
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
    _commit();
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
  );

  /// 탈퇴: 데모 데이터를 처음 상태로 되돌리고 로그아웃한다.
  void deleteAccount() {
    for (final t in _timers.skip(1)) {
      t.cancel();
    }
    _timers.removeRange(1, _timers.length);
    state = DemoDb._seed(_now);
    _session.signOut();
  }

  /// 데모 확인용: 신고 누적 정지 상태 보기
  void previewSuspension() => _session.suspend();

  // ── 체크인 ──────────────────────────────────────────

  /// 장소 이름을 입력해 체크인한다. 같은 이름의 장소가 있으면 거기로, 없으면 새로 연다.
  /// TODO(firebase): spots(이름 키로 찾기/만들기) + checkins 문서 생성
  void checkIn({
    required String placeName,
    required String topic,
    required TopicCategory category,
  }) {
    final me = _db.me!;
    final now = _now;
    final spot = _db.spotByName(placeName) ?? _openSpot(placeName, now);
    final checkin = Checkin(
      id: _db.nextId('my-checkin'),
      uid: DemoDb.myUid,
      spotId: spot.id,
      nickname: me.nickname,
      jobTag: me.jobTag,
      jobCustom: me.jobCustom,
      topic: topic.trim(),
      category: category,
      startedAt: now,
      hasTrustBadge: me.hasTrustBadge,
    );
    _db.checkins.add(checkin);
    _rememberTopic(topic.trim(), category);
    _db.recentSpotIds
      ..remove(spot.id)
      ..insert(0, spot.id);
    if (_db.recentSpotIds.length > AppLimits.recentPlacesCount) {
      _db.recentSpotIds.removeLast();
    }
    _commit();
    _session.checkedIn(checkinId: checkin.id, spotId: spot.id);
    _scheduleIncoming(checkin);
  }

  Spot _openSpot(String name, DateTime now) {
    final spot = Spot(
      id: _db.nextId('spot'),
      name: name.trim(),
      creatorUid: DemoDb.myUid,
      createdAt: now,
    );
    _db.spots.add(spot);
    return spot;
  }

  void addTopic(String topic, TopicCategory category) {
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
        startedAt: _now,
        hasTrustBadge: me.hasTrustBadge,
      ),
    );
    _rememberTopic(topic.trim(), category);
    _commit();
  }

  void updateTopic(String checkinId, String topic, TopicCategory category) {
    final i = _db.checkins.indexWhere((c) => c.id == checkinId);
    if (i < 0) return;
    _db.checkins[i] = _db.checkins[i].copyWith(
      topic: topic.trim(),
      category: category,
    );
    _rememberTopic(topic.trim(), category);
    _commit();
  }

  void removeTopic(String checkinId) {
    final i = _db.checkins.indexWhere((c) => c.id == checkinId);
    if (i < 0) return;
    _db.checkins[i] = _db.checkins[i].copyWith(checkedOutAt: _now);
    _commit();
  }

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
    _commit();
  }

  void checkOut() {
    _checkOutAll(_now);
    _commit();
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
    _commit();
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
        ),
      );
      // 알림은 1번만
      for (final c in still) {
        final i = _db.checkins.indexWhere((x) => x.id == c.id);
        _db.checkins[i] = _db.checkins[i].copyWith(
          notifyWhenSomeoneArrives: false,
        );
      }
      _commit();
      _notice(
        '${u.nickname}님이 체크인했어요: "$topic"',
        actionLabel: '보기',
        route: Routes.spot,
      );
    });
  }

  /// 체크인 직후 같은 스팟 사람이 나에게 신청을 보낸다(데모 시나리오).
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
        // 이미 대화 중이거나 내가 먼저 신청한 사람이면 보내지 않는다.
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
        _commit();
        _notice(
          '${from.nickname}님이 대화를 신청했어요',
          actionLabel: '보기',
          route: Routes.requestDetail(req.id),
        );
      });
    }
  }

  // ── 신청 ────────────────────────────────────────────

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
    _commit();

    _later(DemoSeed.responseDelay, () {
      final current = _db.request(req.id);
      if (current == null || current.status != ChatRequestStatus.pending) {
        return;
      }
      final other = _db.users[target.uid]!;
      final i = _db.requests.indexOf(current);
      if (DemoSeed.rejectingUids.contains(target.uid)) {
        _db.requests[i] = current.copyWith(status: ChatRequestStatus.rejected);
        _commit();
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
      _commit();
      _notice(
        '${other.nickname}님이 신청을 수락했어요',
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

  /// 받은 신청 수락 → 채팅방 id, 거절 → null
  String? respond(String requestId, {required bool accept}) {
    final r = _db.request(requestId);
    if (r == null || r.status != ChatRequestStatus.pending) return r?.chatId;
    final i = _db.requests.indexOf(r);
    if (!accept) {
      _db.requests[i] = r.copyWith(status: ChatRequestStatus.rejected);
      _commit();
      return null;
    }
    final chatId =
        _db.chatWith(r.fromUid, _now)?.id ??
        _createChat(r.fromUid, firstMessage: r.message);
    _db.requests[i] = r.copyWith(
      status: ChatRequestStatus.accepted,
      chatId: chatId,
    );
    _commit();
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
        expiresAt: now.add(AppLimits.chatRetention),
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
    _commit();
  }

  void sendMessage(String chatId, String text) {
    final chat = _db.chat(chatId);
    if (chat == null || text.trim().isEmpty) return;
    _append(chatId, DemoDb.myUid, text.trim());
    final other = chat.otherUid(DemoDb.myUid);
    if (chat.leftUids.contains(other)) return;
    final reply = DemoSeed.replies[_replyCursor++ % DemoSeed.replies.length];
    _later(DemoSeed.replyDelay, () => _partnerSays(chatId, reply));
  }

  void _partnerSays(String chatId, String text) {
    final chat = _db.chat(chatId);
    if (chat == null) return;
    final other = chat.otherUid(DemoDb.myUid);
    if (_db.isBlocked(other)) return;
    _append(chatId, other, text);
    _db.unread[chatId] = (_db.unread[chatId] ?? 0) + 1;
    _commit();
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
    _commit();
  }

  /// 대화방을 나갈 때 평가를 물어볼지(한 번만, 양쪽 모두 말했을 때)
  bool shouldAskReview(String chatId) {
    if (_db.reviewAsked.contains(chatId)) return false;
    final chat = _db.chat(chatId);
    if (chat == null) return false;
    final msgs = _db.messages[chatId] ?? const [];
    return msgs.any((m) => m.senderUid == DemoDb.myUid) &&
        msgs.any((m) => m.senderUid != DemoDb.myUid);
  }

  /// rating == null 이면 건너뛰기. 평가자는 상대에게 공개되지 않는다.
  void review(String chatId, ChatReviewRating? rating) {
    _db.reviewAsked.add(chatId);
    final chat = _db.chat(chatId);
    if (chat != null && rating == ChatReviewRating.good) {
      final other = chat.otherUid(DemoDb.myUid);
      final u = _db.users[other];
      if (u != null) {
        _db.users[other] = u.copyWith(goodReviewCount: u.goodReviewCount + 1);
      }
    }
    _commit();
  }

  // ── 신고·차단 ───────────────────────────────────────

  void block(String uid) {
    final u = _db.user(uid);
    _db.blocks[uid] = Block(
      targetUid: uid,
      targetNickname: u?.nickname ?? '알 수 없음',
      createdAt: _now,
    );
    _commit();
  }

  void unblock(String uid) {
    _db.blocks.remove(uid);
    _commit();
  }

  void report(String uid, ReportReason reason, {required bool alsoBlock}) {
    _db.reportedUids.add(uid);
    if (alsoBlock) {
      block(uid);
    } else {
      _commit();
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
    _commit();
  }

  /// 해지해도 결제한 기간까지는 혜택 유지(US-019)
  void cancelPlus() {
    _db.plusAutoRenew = false;
    _commit();
  }
}

final demoStoreProvider = NotifierProvider<DemoStore, DemoDb>(DemoStore.new);
