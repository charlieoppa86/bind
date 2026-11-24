import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_providers.dart';
import 'package:bind_app/data/demo/demo_seed.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// 바뀐 데이터 묶음을 구독하는 provider만 알림을 받는지 확인한다.
void main() {
  late ProviderContainer container;
  DemoStore store() => container.read(demoStoreProvider.notifier);

  /// provider가 알림을 보낸 횟수를 센다.
  int Function() count<T>(ProviderListenable<T> p) {
    var n = 0;
    container.listen<T>(p, (_, _) => n++);
    return () => n;
  }

  setUp(() {
    container = ProviderContainer();
    store()
      ..signIn()
      ..saveDraftProfile('지후', JobTag.developer)
      ..completeOnboarding()
      ..checkIn(
        place: DemoSeed.places[0],
        topic: '테스트 주제',
        category: TopicCategory.dev,
        ageBand: AgeBand.thirties,
        gender: Gender.female,
      );
  });
  tearDown(() => container.dispose());

  test('메시지를 보내면 그 방의 메시지만 바뀌고 프로필·피드는 그대로다', () async {
    final chats = container.read(visibleChatsProvider);
    expect(chats.length, greaterThanOrEqualTo(2));
    final a = chats[0].id;
    final b = chats[1].id;

    final me = count(meProvider);
    final feed = count(feedProvider('seongsu'));
    final pending = count(pendingReceivedCountProvider);
    final roomA = count(messagesProvider(a));
    final roomB = count(messagesProvider(b));

    store().sendMessage(a, '안녕하세요');
    await container.pump();

    expect(roomA(), 1);
    expect(roomB(), 0);
    expect(me(), 0);
    expect(feed(), 0);
    expect(pending(), 0);
  });

  test('차단은 피드를 바꾸지만 프로필·BIND+ 상태는 알리지 않는다', () async {
    final feedNow = container.read(feedProvider('seongsu'));
    final me = count(meProvider);
    final plus = count(isPlusActiveProvider);
    final feed = count(feedProvider('seongsu'));

    store().block(feedNow.first.uid);
    await container.pump();

    expect(feed(), 1);
    expect(me(), 0);
    expect(plus(), 0);
  });

  test('값이 같으면 숫자 배지는 다시 그리지 않는다', () async {
    final unread = count(unreadTotalProvider);
    // 체크인 정보만 바뀌는 동작(안 읽은 수와 무관)
    store().setArrivalNotify(true);
    await container.pump();
    expect(unread(), 0);
  });
}
