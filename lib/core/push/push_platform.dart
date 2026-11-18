import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 알림 권한 상태
enum PushPermission { unknown, granted, provisional, denied }

/// 플랫폼에서 받은 원시 알림(FCM RemoteMessage를 앱 안 모양으로 옮긴 것)
class RawPush {
  const RawPush({
    required this.id,
    this.title,
    this.body,
    this.data = const {},
  });

  factory RawPush.fromRemote(RemoteMessage m) => RawPush(
    id:
        m.messageId ??
        '${m.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
    title: m.notification?.title,
    body: m.notification?.body,
    data: m.data,
  );

  final String id;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// 푸시 기능의 플랫폼 부분. 실제 앱은 [FirebasePushPlatform],
/// 데모 모드·테스트는 [NoopPushPlatform]을 쓴다.
abstract interface class PushPlatform {
  Future<void> init();
  Future<PushPermission> permission();

  /// iOS 알림 권한 팝업, Android 13+ POST_NOTIFICATIONS 런타임 권한
  Future<PushPermission> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();

  /// 앱이 켜져 있을 때 받은 알림
  Stream<RawPush> get onForeground;

  /// 백그라운드 상태에서 알림을 눌러 앱이 앞으로 나왔을 때
  Stream<RawPush> get onOpened;

  /// 종료 상태에서 알림을 눌러 앱이 실행됐을 때(한 번만 돌려준다)
  Future<RawPush?> initialMessage();
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
  String get platformName;
}

class FirebasePushPlatform implements PushPlatform {
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  /// 서버가 보내는 알림 채널(AndroidManifest의 기본 채널과 같다)
  static const channelId = 'bind_default';

  @override
  Future<void> init() async {
    // Android: 중요도 높은 채널을 만들어 두어야 헤드업으로 뜬다.
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_bind'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'BIND 알림',
            description: '대화 요청·수락·새 메시지 알림',
            importance: Importance.high,
          ),
        );
    // 앱이 켜져 있을 때는 시스템 알림 대신 앱 안 배너로 보여 준다.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized => PushPermission.granted,
    AuthorizationStatus.provisional => PushPermission.provisional,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.unknown,
  };

  @override
  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> getToken() async {
    try {
      // iOS는 APNs 토큰이 먼저 있어야 한다(시뮬레이터·APNs 키 미등록이면 없음).
      if (Platform.isIOS && await _messaging.getAPNSToken() == null) {
        return null;
      }
      // firebase_messaging 17의 register()/onRegistered는 설치 ID(FID)를 발송 대상으로 쓴다.
      // 서버(firebase-admin)가 FID 발송을 지원하면 옮긴다. 지금은 확실히 되는 FCM 토큰을 쓴다.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[BIND] 푸시 토큰을 받지 못했어요: $e');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<RawPush> get onForeground =>
      FirebaseMessaging.onMessage.map(RawPush.fromRemote);

  @override
  Stream<RawPush> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(RawPush.fromRemote);

  @override
  Future<RawPush?> initialMessage() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : RawPush.fromRemote(m);
  }

  @override
  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  @override
  String get platformName => Platform.isIOS ? 'ios' : 'android';
}

/// 데모 모드·테스트용: 아무것도 하지 않는다.
class NoopPushPlatform implements PushPlatform {
  const NoopPushPlatform();

  @override
  Future<void> init() async {}
  @override
  Future<PushPermission> permission() async => PushPermission.unknown;
  @override
  Future<PushPermission> requestPermission() async => PushPermission.unknown;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<RawPush> get onForeground => const Stream.empty();
  @override
  Stream<RawPush> get onOpened => const Stream.empty();
  @override
  Future<RawPush?> initialMessage() async => null;
  @override
  Future<void> subscribe(String topic) async {}
  @override
  Future<void> unsubscribe(String topic) async {}
  @override
  String get platformName => 'demo';
}

/// 지금 쓰는 푸시 플랫폼. Firebase가 준비되면 main.dart가 [FirebasePushPlatform]으로 바꾼다.
final pushPlatformProvider = Provider<PushPlatform>(
  (ref) => const NoopPushPlatform(),
);
