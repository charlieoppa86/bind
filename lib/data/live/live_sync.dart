import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/constants/enums.dart';
import '../../core/notice/in_app_notice.dart';
import '../demo/demo_store.dart';
import '../models/app_user.dart';
import '../models/safety.dart';
import '../models/spot.dart';
import '../models/chat.dart';
import '../models/chat_request.dart';
import '../models/checkin.dart';
import '../../features/session/session.dart';
import 'live_mode.dart';
import 'checkin_repository_provider.dart';

/// 실제(Firebase) 모드에서 Firestore 실시간 데이터를 앱 안 저장소에 넣는다.
///
/// 화면은 지금처럼 저장소의 파생 provider만 보고, 바뀐 부분만 다시 그린다.
/// - 내 체크아웃 전 카드 → 세션(체크인 여부)과 내 카드
/// - 내가 있는 장소의 카드·장소 정보 → 피드와 인원
/// - 받은·보낸 대화 요청, 내 채팅방 → 요청함·채팅 탭(새 요청·수락은 앱 안 알림)
/// - 요청·채팅 상대의 프로필 → 닉네임·하는 일
/// - 내 차단 목록, 내 프로필 변화(정지되면 바로 정지 화면으로)
///
/// 서버의 내 uid는 앱 안에서 [DemoDb.myUid]로 바꿔 넣는다.
class LiveSync {
  LiveSync(this._ref);

  final Ref _ref;
  String? _uid;
  String? _spotId;
  StreamSubscription<List<Checkin>>? _mine;
  StreamSubscription<List<Checkin>>? _spotCards;
  StreamSubscription<Object?>? _spot;
  StreamSubscription<Object?>? _received;
  StreamSubscription<Object?>? _sent;
  StreamSubscription<Object?>? _chats;
  StreamSubscription<Object?>? _blocks;
  StreamSubscription<Object?>? _me;

  /// 알림을 띄울지 판단하려고 기억해 두는 이전 상태
  Set<String>? _knownReceived;
  Map<String, ChatRequestStatus>? _sentStatus;
  final _fetchedUsers = <String>{};

  CheckinRepository get _repo => _ref.read(checkinRepositoryProvider);
  DemoStore get _store => _ref.read(demoStoreProvider.notifier);

  /// 앱 시작 때 기다리는 첫 응답들. 모두 오면 스플래시가 홈으로 넘어간다.
  static const _initialData = [
    'mine', // 내 카드(체크인 여부)
    'spotCards', // 내 장소의 다른 사람 카드
    'spotInfo', // 내 장소 이름·인원
    'received', // 받은 요청
    'sent', // 보낸 요청
    'chats', // 채팅방·안 읽은 수
    'blocks', // 차단 목록
    'me', // 내 프로필(정지·좋았어요 수)
  ];
  final _gates = <String, Completer<void>>{};

  /// [key] 데이터의 첫 응답이 왔다(실패해도 기다림은 끝낸다).
  void _ready(String key) {
    final gate = _gates[key];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// 로그인 직후 부른다. 홈 화면에 필요한 데이터([_initialData])의 첫 응답을
  /// 모두 받을 때까지 기다린다. 그동안 스플래시가 보이고, 끝나면 홈으로 간다.
  /// 네트워크가 느려도 [timeout]이 지나면 들어간다(나머지는 도착하는 대로 채워진다).
  Future<void> start(
    String uid, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_uid == uid && _mine != null) return;
    stop();
    _uid = uid;
    _gates
      ..clear()
      ..addAll({for (final k in _initialData) k: Completer<void>()});
    _mine = _repo
        .watchMyActive(uid)
        .listen(
          (cards) {
            final mine = [for (final c in cards) c.withUid(DemoDb.myUid)]
              ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
            _store.applyMyCheckins(mine);
            _watchSpot(mine.firstOrNull?.spotId);
            _ready('mine');
          },
          onError: (Object e) {
            debugPrint('[BIND] 내 체크인 구독 실패: $e');
            _ready('mine');
            _ready('spotCards');
            _ready('spotInfo');
          },
        );
    _watchRequestsAndChats(uid);
    _watchSafety(uid);
    await Future.wait([for (final g in _gates.values) g.future]).timeout(
      timeout,
      onTimeout: () {
        final late = [
          for (final e in _gates.entries)
            if (!e.value.isCompleted) e.key,
        ];
        debugPrint('[BIND] 시작 데이터 일부가 늦어 먼저 들어가요: $late');
        return const [];
      },
    );
  }

  /// 서버 uid → 앱 안 uid(내 uid는 [DemoDb.myUid])
  String _local(String uid) => uid == _uid ? DemoDb.myUid : uid;

  ChatRequest _localRequest(ChatRequest r) => ChatRequest(
    id: r.id,
    fromUid: _local(r.fromUid),
    toUid: _local(r.toUid),
    spotId: r.spotId,
    toCheckinId: r.toCheckinId,
    message: r.message,
    status: r.status,
    createdAt: r.createdAt,
    expiresAt: r.expiresAt,
    fromNickname: r.fromNickname,
    fromJobTag: r.fromJobTag,
    fromJobCustom: r.fromJobCustom,
    chatId: r.chatId,
  );

  Chat _localChat(Chat c) => Chat(
    id: c.id,
    memberUids: [for (final u in c.memberUids) _local(u)],
    createdAt: c.createdAt,
    expiresAt: c.expiresAt,
    lastMessage: c.lastMessage,
    lastMessageAt: c.lastMessageAt,
    messageCounts: c.messageCounts,
    leftUids: [for (final u in c.leftUids) _local(u)],
  );

  /// 첫 응답이 오면(실패해도) [key] 기다림을 끝내는 구독 헬퍼
  StreamSubscription<T> _listen<T>(
    Stream<T> stream,
    String key,
    String label,
    void Function(T value) onData,
  ) => stream.listen(
    (value) {
      onData(value);
      _ready(key);
    },
    onError: (Object e) {
      debugPrint('[BIND] $label 구독 실패: $e');
      _ready(key);
    },
  );

  void _watchRequestsAndChats(String uid) {
    final requests = _ref.read(requestRepositoryProvider);
    _received = _listen<List<ChatRequest>>(
      requests.watchReceived(uid),
      'received',
      '받은 요청',
      (list) {
        final local = [for (final r in list) _localRequest(r)];
        _store.applyReceivedRequests(local);
        _noticeNewRequests(local);
        _fetchUsers([for (final r in local) r.fromUid]);
      },
    );
    _sent = _listen<List<ChatRequest>>(
      requests.watchSent(uid),
      'sent',
      '보낸 요청',
      (list) {
        final local = [for (final r in list) _localRequest(r)];
        _fetchUsers([for (final r in local) r.toUid]);
        _store.applySentRequests(local);
        _noticeAnswers(local);
      },
    );
    _chats = _listen<List<(Chat, int)>>(
      requests.watchChats(uid),
      'chats',
      '채팅방',
      (list) {
        final local = [for (final (c, n) in list) (_localChat(c), n)];
        _fetchUsers([for (final (c, _) in local) c.otherUid(DemoDb.myUid)]);
        _store.applyChats(local);
      },
    );
  }

  void _watchSafety(String uid) {
    final safety = _ref.read(safetyRepositoryProvider);
    _blocks = _listen<List<Block>>(
      safety.watchBlocks(uid),
      'blocks',
      '차단 목록',
      _store.applyBlocks,
    );
    _me = _listen<AppUser?>(safety.watchMe(uid), 'me', '내 프로필', (me) {
      if (me != null && me.isOnboarded) _store.applyMe(me);
    });
  }

  /// 처음 받은 목록은 기억만 하고, 그 뒤에 새로 온 요청만 알린다.
  void _noticeNewRequests(List<ChatRequest> received) {
    final known = _knownReceived;
    _knownReceived = {for (final r in received) r.id};
    if (known == null) return;
    for (final r in received) {
      if (known.contains(r.id) || r.status != ChatRequestStatus.pending) {
        continue;
      }
      _notice(
        '${r.fromNickname}님이 대화를 요청했어요: "${r.message}"',
        actionLabel: '보기',
        route: Routes.requestDetail(r.id),
      );
    }
  }

  /// 내가 보낸 요청이 수락·거절되면 알린다.
  void _noticeAnswers(List<ChatRequest> sent) {
    final before = _sentStatus;
    _sentStatus = {for (final r in sent) r.id: r.status};
    if (before == null) return;
    for (final r in sent) {
      if (before[r.id] != ChatRequestStatus.pending) continue;
      final name = _ref.read(demoStoreProvider).user(r.toUid)?.nickname ?? '상대';
      if (r.status == ChatRequestStatus.accepted && r.chatId != null) {
        _notice(
          '$name님이 대화 요청을 수락했어요',
          actionLabel: '대화하기',
          route: Routes.chatRoom(r.chatId!),
        );
      } else if (r.status == ChatRequestStatus.rejected) {
        _notice(
          '$name님은 이번엔 어렵대요',
          actionLabel: '보기',
          route: Routes.requestsSent,
        );
      }
    }
  }

  void _notice(String message, {String? actionLabel, String? route}) => _ref
      .read(inAppNoticeProvider.notifier)
      .show(InAppNotice(message, actionLabel: actionLabel, route: route));

  /// 아직 모르는 상대 프로필만 한 번 읽어 온다.
  void _fetchUsers(Iterable<String> uids) {
    final missing = {
      for (final u in uids)
        if (u.isNotEmpty && u != DemoDb.myUid && _fetchedUsers.add(u)) u,
    };
    if (missing.isEmpty) return;
    _ref
        .read(requestRepositoryProvider)
        .fetchUsers(missing)
        .then(_store.applyUsers)
        .catchError((Object e) {
          _fetchedUsers.removeAll(missing);
          debugPrint('[BIND] 상대 프로필 조회 실패: $e');
        });
  }

  void _watchSpot(String? spotId) {
    if (spotId == _spotId) return;
    _spotCards?.cancel();
    _spot?.cancel();
    _spotId = spotId;
    if (spotId == null) {
      _store.applySpotCheckins(null, const []);
      _ready('spotCards');
      _ready('spotInfo');
      return;
    }
    _spotCards = _listen<List<Checkin>>(
      _repo.watchSpotActive(spotId),
      'spotCards',
      '피드',
      (cards) {
        _store.applySpotCheckins(spotId, [
          for (final c in cards)
            if (c.uid != _uid) c,
        ]);
      },
    );
    _spot = _listen<Spot?>(_repo.watchSpot(spotId), 'spotInfo', '장소', (spot) {
      if (spot != null) _store.applySpots([spot]);
    });
  }

  /// 로그아웃·탈퇴 때 구독을 모두 끊는다.
  void stop() {
    _mine?.cancel();
    _spotCards?.cancel();
    _spot?.cancel();
    _received?.cancel();
    _sent?.cancel();
    _chats?.cancel();
    _blocks?.cancel();
    _me?.cancel();
    _mine = _spotCards = null;
    _spot = _received = _sent = _chats = _blocks = _me = null;
    _uid = _spotId = null;
    _knownReceived = null;
    for (final g in _gates.values) {
      if (!g.isCompleted) g.complete();
    }
    _gates.clear();
    _sentStatus = null;
    _fetchedUsers.clear();
  }
}

final liveSyncProvider = Provider<LiveSync>((ref) {
  final sync = LiveSync(ref);
  ref.onDispose(sync.stop);
  return sync;
});

/// 대화방을 보고 있는 동안만 그 방 메시지를 실시간으로 받는다(실제 모드).
/// 메시지 목록 위젯이 구독하고, 화면을 떠나면 자동으로 끊긴다.
final chatMessagesSyncProvider = Provider.autoDispose.family<void, String>((
  ref,
  chatId,
) {
  if (!ref.watch(liveModeProvider)) return;
  final uid = ref.read(sessionProvider).uid;
  if (uid == null) return;
  String local(String u) => u == uid ? DemoDb.myUid : u;
  final sub = ref
      .read(requestRepositoryProvider)
      .watchMessages(chatId)
      .listen(
        (list) => ref.read(demoStoreProvider.notifier).applyMessages(chatId, [
          for (final m in list)
            ChatMessage(
              id: m.id,
              senderUid: local(m.senderUid),
              text: m.text,
              sentAt: m.sentAt,
            ),
        ]),
        onError: (Object e) => debugPrint('[BIND] 메시지 구독 실패: $e'),
      );
  ref.onDispose(sub.cancel);
});
