import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../data/live/push_repository.dart';
import '../../features/session/session.dart';
import '../notice/in_app_notice.dart';
import 'push_message.dart';
import 'push_platform.dart';

/// 공개 토픽. 설정 화면에서 켜고 끈다.
abstract final class PushTopics {
  /// 공지·이벤트(운영자가 토픽으로 한 번에 보낸다)
  static const notice = 'notice';

  /// 설정 화면에 보이는 토픽과 이름
  static const labels = {notice: '공지·이벤트 알림'};

  /// 기본으로 켜 두는 토픽
  static const defaults = {notice};

  /// 사람마다 하나씩 있는 개인 토픽(개발용 테스트 발송)
  static String personal(String uid) => 'u_$uid';
}

class PushState {
  const PushState({
    this.permission = PushPermission.unknown,
    this.token,
    this.topics = const {},
    this.inbox = const [],
    this.pendingRoute,
  });

  final PushPermission permission;
  final String? token;

  /// 켜 둔 공개 토픽([PushTopics.labels]의 키)
  final Set<String> topics;

  /// 받은 알림(최신순, 최대 [PushController.inboxLimit]개)
  final List<PushMessage> inbox;

  /// 로그인 전에 눌린 알림의 화면. 로그인이 끝나면 연다.
  final String? pendingRoute;

  int get unread => inbox.where((m) => !m.read).length;
  bool get enabled =>
      permission == PushPermission.granted ||
      permission == PushPermission.provisional;

  PushState copyWith({
    PushPermission? permission,
    String? Function()? token,
    Set<String>? topics,
    List<PushMessage>? inbox,
    String? Function()? pendingRoute,
  }) => PushState(
    permission: permission ?? this.permission,
    token: token != null ? token() : this.token,
    topics: topics ?? this.topics,
    inbox: inbox ?? this.inbox,
    pendingRoute: pendingRoute != null ? pendingRoute() : this.pendingRoute,
  );
}

/// 푸시 알림 상태(권한·토큰·토픽·받은 알림)와 알림을 눌렀을 때의 화면 이동.
///
/// - 앱 켜짐(포그라운드): 받은 알림을 상태에 넣고 화면 위 배너로 보여 준다.
/// - 백그라운드: OS가 알림을 띄우고, 누르면 앱이 열리며 그 화면으로 간다.
/// - 종료 상태: 알림을 눌러 앱이 실행되면 로그인이 끝난 뒤 그 화면으로 간다.
class PushController extends Notifier<PushState> {
  static const inboxLimit = 50;

  final _subs = <StreamSubscription<Object?>>[];
  String? _uid;

  PushPlatform get _platform => ref.read(pushPlatformProvider);
  PushRepository get _repo => ref.read(pushRepositoryProvider);

  @override
  PushState build() {
    ref.onDispose(_cancel);
    // 로그인 전에 눌린 알림은 세션이 준비되면 연다.
    ref.listen(sessionProvider, (_, s) {
      final route = state.pendingRoute;
      if (s.status == SessionStatus.ready && route != null) _navigate(route);
    });
    return const PushState();
  }

  /// 로그인(온보딩 완료) 뒤 부른다. 알림을 받을 준비를 하고 권한을 묻는다.
  Future<void> start(String uid) async {
    if (_uid == uid) return;
    _cancel();
    _uid = uid;
    await _platform.init();
    // 권한 팝업보다 먼저 수신 경로를 열어 두어야 눌린 알림을 놓치지 않는다.
    _subs
      ..add(
        _platform.onForeground.listen(
          (r) => _receive(r, PushOrigin.foreground),
        ),
      )
      ..add(
        _platform.onOpened.listen((r) => _receive(r, PushOrigin.background)),
      )
      ..add(_platform.onTokenRefresh.listen(_saveToken));
    final initial = await _platform.initialMessage();
    if (initial != null) _receive(initial, PushOrigin.terminated);

    final permission = await _platform.requestPermission();
    state = state.copyWith(permission: permission);
    await _registerToken();
    await _syncTopics(uid);
  }

  /// 로그아웃·탈퇴 전에 부른다. 이 기기 토큰을 지우고 토픽 구독을 푼다.
  Future<void> stop() async {
    final uid = _uid;
    final token = state.token;
    _cancel();
    _uid = null;
    try {
      if (uid != null && token != null) await _repo.deleteToken(uid, token);
      if (uid != null) await _platform.unsubscribe(PushTopics.personal(uid));
      for (final t in state.topics) {
        await _platform.unsubscribe(t);
      }
      await _platform.deleteToken();
    } catch (e) {
      debugPrint('[BIND] 푸시 정리 실패: $e');
    }
    state = const PushState();
  }

  /// 설정 화면의 "알림 허용하기"
  Future<PushPermission> requestPermission() async {
    final permission = await _platform.requestPermission();
    state = state.copyWith(permission: permission);
    if (state.token == null) await _registerToken();
    return permission;
  }

  /// 공개 토픽 켜고 끄기(서버에도 저장해 다른 기기·재설치에서 이어진다)
  Future<void> setTopic(String topic, {required bool on}) async {
    final uid = _uid;
    if (uid == null) return;
    final next = {...state.topics};
    on ? next.add(topic) : next.remove(topic);
    state = state.copyWith(topics: next);
    try {
      on
          ? await _platform.subscribe(topic)
          : await _platform.unsubscribe(topic);
      await _repo.saveTopics(uid, next);
    } catch (e) {
      debugPrint('[BIND] 토픽 변경 실패: $e');
    }
  }

  /// 알림 목록에서 눌렀을 때: 읽음 처리하고 그 화면으로
  void open(PushMessage m) {
    _markRead(m.id);
    final route = m.route;
    if (route != null) _navigate(route);
  }

  void markAllRead() => state = state.copyWith(
    inbox: [for (final m in state.inbox) m.read ? m : m.copyWith(read: true)],
  );

  // ── 내부 ──

  Future<void> _registerToken() async {
    if (!state.enabled) return;
    final token = await _platform.getToken();
    if (token == null) return;
    state = state.copyWith(token: () => token);
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(token: () => token);
    try {
      await _repo.saveToken(uid, token, _platform.platformName);
    } catch (e) {
      debugPrint('[BIND] 푸시 토큰 저장 실패: $e');
    }
  }

  Future<void> _syncTopics(String uid) async {
    try {
      final saved = await _repo.loadTopics(uid);
      final topics = saved ?? PushTopics.defaults;
      for (final t in topics) {
        await _platform.subscribe(t);
      }
      await _platform.subscribe(PushTopics.personal(uid));
      state = state.copyWith(topics: topics);
    } catch (e) {
      debugPrint('[BIND] 토픽 구독 실패: $e');
    }
  }

  void _receive(RawPush raw, PushOrigin origin) {
    final data = raw.data;
    final message = PushMessage(
      id: raw.id,
      title: raw.title ?? data['title'] as String? ?? 'BIND',
      body: raw.body ?? data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'notice',
      route: PushRoute.parse(data['route']),
      receivedAt: DateTime.now(),
      // 알림을 눌러서 들어온 것은 이미 본 것으로 친다.
      read: origin != PushOrigin.foreground,
      origin: origin,
    );
    state = state.copyWith(
      inbox: [
        message,
        for (final m in state.inbox)
          if (m.id != message.id) m,
      ].take(inboxLimit).toList(),
    );
    if (origin == PushOrigin.foreground) {
      _banner(message);
    } else if (message.route != null) {
      _navigate(message.route!);
    }
  }

  /// 요청 도착·수락·거절·만료는 실시간 동기화(LiveSync)가 이미 배너를 띄우므로 겹치지 않게 한다.
  /// 새 메시지는 그 대화방을 보고 있으면 띄우지 않는다.
  static const _syncedTypes = {'request', 'accepted', 'rejected', 'expired'};

  void _banner(PushMessage m) {
    if (_syncedTypes.contains(m.type)) return;
    if (m.route != null && ref.read(currentRoutePathProvider)() == m.route) {
      return;
    }
    ref
        .read(inAppNoticeProvider.notifier)
        .show(
          InAppNotice(
            m.body.isEmpty ? m.title : '${m.title} · ${m.body}',
            actionLabel: m.route == null ? null : '보기',
            route: m.route,
          ),
        );
  }

  void _markRead(String id) => state = state.copyWith(
    inbox: [
      for (final m in state.inbox) m.id == id ? m.copyWith(read: true) : m,
    ],
  );

  /// 로그인이 끝났으면 바로, 아니면 끝난 뒤에 연다.
  void _navigate(String route) {
    if (ref.read(sessionProvider).status != SessionStatus.ready) {
      state = state.copyWith(pendingRoute: () => route);
      return;
    }
    state = state.copyWith(pendingRoute: () => null);
    ref.read(pushNavigatorProvider)(route);
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}

final pushProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);

/// 알림을 눌렀을 때 화면 이동(테스트에서 바꿔 끼운다).
/// 라우터 가드(로그인 → 홈)가 먼저 끝나도록 다음 프레임에 이동하고, 앱이 쉬고 있어도
/// 그 프레임이 오도록 화면 갱신을 요청한다.
final pushNavigatorProvider = Provider<void Function(String route)>(
  (ref) => (route) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => ref.read(routerProvider).go(route))
      ..ensureVisualUpdate();
  },
);

/// 지금 보고 있는 화면 경로(같은 대화방 알림은 배너를 띄우지 않으려고)
final currentRoutePathProvider = Provider<String Function()>(
  (ref) =>
      () =>
          ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path,
);
