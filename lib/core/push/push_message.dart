/// 받은 푸시 알림 한 건(앱 안 상태로 들고 있는 모양).
///
/// 서버(Cloud Functions)는 알림 제목·본문과 함께 data에 `type`·`route`를 넣어 보낸다.
class PushMessage {
  const PushMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.route,
    this.read = false,
    this.origin = PushOrigin.foreground,
  });

  final String id;
  final String title;
  final String body;

  /// request · accepted · rejected · expired · message · arrival · notice · test
  final String type;

  /// 눌렀을 때 갈 앱 안 화면(허용된 경로만, [PushRoute.parse])
  final String? route;
  final DateTime receivedAt;
  final bool read;

  /// 어떤 상태에서 받았는지(앱 켜짐 / 알림을 눌러 앱이 열림 / 종료 상태에서 눌러 실행)
  final PushOrigin origin;

  PushMessage copyWith({bool? read}) => PushMessage(
    id: id,
    title: title,
    body: body,
    type: type,
    receivedAt: receivedAt,
    route: route,
    read: read ?? this.read,
    origin: origin,
  );
}

enum PushOrigin { foreground, background, terminated }

/// 알림의 딥링크 경로 검사. 앱 안 화면 경로만 허용하고 나머지는 버린다
/// (외부 주소·임의 경로로 이동시키는 알림을 막는다).
abstract final class PushRoute {
  static const _allowed = ['/requests', '/chats', '/spot', '/my', '/checkin'];

  static String? parse(Object? raw) {
    if (raw is! String) return null;
    final route = raw.trim();
    if (!route.startsWith('/') || route.startsWith('//')) return null;
    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final ok = _allowed.any((p) => uri.path == p || uri.path.startsWith('$p/'));
    return ok ? route : null;
  }
}
