import 'dart:async';

import 'package:bind_app/core/notice/in_app_notice.dart';
import 'package:bind_app/core/push/push_controller.dart';
import 'package:bind_app/core/push/push_message.dart';
import 'package:bind_app/core/push/push_platform.dart';
import 'package:bind_app/data/live/push_repository.dart';
import 'package:bind_app/features/session/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// FCM 대신 쓰는 가짜 플랫폼
class FakePushPlatform implements PushPlatform {
  final foreground = StreamController<RawPush>.broadcast();
  final opened = StreamController<RawPush>.broadcast();
  final refresh = StreamController<String>.broadcast();
  RawPush? initial;
  PushPermission grant = PushPermission.granted;
  final subscribed = <String>{};
  bool tokenDeleted = false;

  @override
  Future<void> init() async {}
  @override
  Future<PushPermission> permission() async => grant;
  @override
  Future<PushPermission> requestPermission() async => grant;
  @override
  Future<String?> getToken() async => 'token-1';
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<void> deleteToken() async => tokenDeleted = true;
  @override
  Stream<RawPush> get onForeground => foreground.stream;
  @override
  Stream<RawPush> get onOpened => opened.stream;
  @override
  Future<RawPush?> initialMessage() async {
    final m = initial;
    initial = null;
    return m;
  }

  @override
  Future<void> subscribe(String topic) async => subscribed.add(topic);
  @override
  Future<void> unsubscribe(String topic) async => subscribed.remove(topic);
  @override
  String get platformName => 'android';
}

/// Firestore 대신 쓰는 가짜 저장소
class FakePushRepository implements PushRepository {
  final tokens = <String>{};
  Set<String>? topics;

  @override
  Future<void> saveToken(String uid, String token, String platform) async =>
      tokens.add(token);
  @override
  Future<void> deleteToken(String uid, String token) async =>
      tokens.remove(token);
  @override
  Future<Set<String>?> loadTopics(String uid) async => topics;
  @override
  Future<void> saveTopics(String uid, Set<String> t) async => topics = t;
  @override
  Future<void> sendTest({required bool viaTopic, int delaySeconds = 0}) async {}
}

RawPush push(String type, {String? route, String id = 'm1'}) => RawPush(
  id: id,
  title: '제목',
  body: '본문',
  data: {'type': type, 'route': ?route},
);

void main() {
  late FakePushPlatform platform;
  late FakePushRepository repo;
  late ProviderContainer container;
  late List<String> navigated;
  PushController push_() => container.read(pushProvider.notifier);
  PushState state() => container.read(pushProvider);

  setUp(() {
    platform = FakePushPlatform();
    repo = FakePushRepository();
    navigated = [];
    container = ProviderContainer(
      overrides: [
        pushPlatformProvider.overrideWithValue(platform),
        pushRepositoryProvider.overrideWithValue(repo),
        pushNavigatorProvider.overrideWithValue(navigated.add),
        currentRoutePathProvider.overrideWithValue(() => '/spot'),
      ],
    );
    container.read(pushProvider); // 세션 구독 시작
  });
  tearDown(() => container.dispose());

  void ready() => container
      .read(sessionProvider.notifier)
      .signedIn(uid: 'u1', isOnboarded: true);

  test('딥링크는 앱 안 화면 경로만 허용한다', () {
    expect(PushRoute.parse('/chats/abc'), '/chats/abc');
    expect(PushRoute.parse('/requests/received/r1'), '/requests/received/r1');
    expect(PushRoute.parse('https://evil.example/x'), isNull);
    expect(PushRoute.parse('//evil.example'), isNull);
    expect(PushRoute.parse('/admin'), isNull);
    expect(PushRoute.parse(42), isNull);
  });

  test('시작하면 권한·토큰을 받고 기본 토픽과 개인 토픽을 구독한다', () async {
    ready();
    await push_().start('u1');
    expect(state().permission, PushPermission.granted);
    expect(state().token, 'token-1');
    expect(repo.tokens, {'token-1'});
    expect(state().topics, PushTopics.defaults);
    expect(platform.subscribed, {...PushTopics.defaults, 'u_u1'});
  });

  test('앱이 켜져 있을 때 받은 알림은 상태에 바로 쌓이고 배너로 보인다', () async {
    ready();
    await push_().start('u1');
    platform.foreground.add(push('message', route: '/chats/c1'));
    await Future<void>.delayed(Duration.zero);
    expect(state().inbox.single.route, '/chats/c1');
    expect(state().unread, 1);
    expect(container.read(inAppNoticeProvider)?.route, '/chats/c1');
    expect(navigated, isEmpty); // 포그라운드는 자동으로 이동하지 않는다
  });

  test('요청 알림은 실시간 동기화가 배너를 띄우므로 겹쳐 띄우지 않는다', () async {
    ready();
    await push_().start('u1');
    platform.foreground.add(push('request', route: '/requests/received/r1'));
    await Future<void>.delayed(Duration.zero);
    expect(state().inbox, hasLength(1));
    expect(container.read(inAppNoticeProvider), isNull);
  });

  test('백그라운드에서 알림을 누르면 그 화면으로 간다', () async {
    ready();
    await push_().start('u1');
    platform.opened.add(push('accepted', route: '/chats/c9'));
    await Future<void>.delayed(Duration.zero);
    expect(navigated, ['/chats/c9']);
    expect(state().inbox.single.read, isTrue);
  });

  test('종료 상태에서 눌린 알림은 로그인이 끝난 뒤 그 화면으로 간다', () async {
    platform.initial = push('request', route: '/requests/received/r2');
    await push_().start('u1'); // 아직 세션 준비 전(스플래시)
    expect(state().pendingRoute, '/requests/received/r2');
    expect(navigated, isEmpty);
    ready();
    expect(navigated, ['/requests/received/r2']);
    expect(state().pendingRoute, isNull);
  });

  test('허용되지 않은 경로의 알림은 이동하지 않는다', () async {
    ready();
    await push_().start('u1');
    platform.opened.add(push('notice', route: 'https://evil.example'));
    await Future<void>.delayed(Duration.zero);
    expect(navigated, isEmpty);
    expect(state().inbox.single.route, isNull);
  });

  test('토픽을 끄고 켜면 구독과 저장이 함께 바뀐다', () async {
    ready();
    await push_().start('u1');
    await push_().setTopic(PushTopics.notice, on: false);
    expect(platform.subscribed.contains(PushTopics.notice), isFalse);
    expect(repo.topics, isEmpty);
    await push_().setTopic(PushTopics.notice, on: true);
    expect(platform.subscribed.contains(PushTopics.notice), isTrue);
  });

  test('로그아웃하면 토큰을 지우고 구독을 푼다', () async {
    ready();
    await push_().start('u1');
    await push_().stop();
    expect(repo.tokens, isEmpty);
    expect(platform.tokenDeleted, isTrue);
    expect(platform.subscribed, isEmpty);
    expect(state().inbox, isEmpty);
  });

  test('권한이 없으면 토큰을 저장하지 않는다', () async {
    platform.grant = PushPermission.denied;
    ready();
    await push_().start('u1');
    expect(state().permission, PushPermission.denied);
    expect(repo.tokens, isEmpty);
  });
}
