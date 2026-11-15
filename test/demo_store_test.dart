import 'package:bind_app/core/constants/app_limits.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:bind_app/core/utils/geo.dart';
import 'package:bind_app/features/session/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_location.dart';

void main() {
  late ProviderContainer container;
  DemoStore store() => container.read(demoStoreProvider.notifier);
  DemoDb db() => container.read(demoStoreProvider);

  setUp(() {
    container = ProviderContainer();
    store()
      ..signIn()
      ..saveDraftProfile('지후', JobTag.developer)
      ..completeOnboarding();
  });
  tearDown(() => container.dispose());

  test('스팟 코드 5번 틀리면 잠긴다', () {
    for (var i = 1; i < AppLimits.spotCodeMaxAttempts; i++) {
      expect(
        store().verifyCode('seongsu', '0000', at: seongsuFront),
        isA<CodeWrong>(),
      );
    }
    expect(
      store().verifyCode('seongsu', '0000', at: seongsuFront),
      isA<CodeLocked>(),
    );
    // 잠긴 동안은 맞는 코드도 막힌다
    expect(
      store().verifyCode('seongsu', '2580', at: seongsuFront),
      isA<CodeLocked>(),
    );
  });

  test('체크인하면 세션이 바뀌고 피드에 다른 사람 카드가 보인다', () {
    store().checkIn(
      spotId: 'seongsu',
      topic: '테스트 주제',
      category: TopicCategory.dev,
      stay: StayDuration.oneHour,
    );
    expect(container.read(sessionProvider).isCheckedIn, isTrue);
    expect(db().feed('seongsu', DateTime.now()), isNotEmpty);
    expect(db().recentTopics.first.$1, '테스트 주제');
  });

  test('같은 사람에게는 대기 중 신청 1개, 무료는 하루 5번까지', () {
    store().checkIn(
      spotId: 'pangyo-conf',
      topic: '테스트',
      category: TopicCategory.other,
      stay: StayDuration.oneHour,
    );
    final feed = db().feed('pangyo-conf', DateTime.now());
    expect(store().sendRequest(feed[0], '안녕하세요'), SendRequestResult.sent);
    expect(store().sendRequest(feed[0], '또 보내요'), SendRequestResult.duplicate);

    // 시드에 오늘 보낸 신청 기록이 있을 수 있으니 한도까지 채운다
    var i = 1;
    while (db().sentToday(DateTime.now()) < AppLimits.freeDailyRequests) {
      expect(store().sendRequest(feed[i++], '안녕하세요'), SendRequestResult.sent);
    }
    expect(store().sendRequest(feed[i], '안녕하세요'), SendRequestResult.dailyLimit);

    store().subscribePlus();
    expect(store().sendRequest(feed[i], '안녕하세요'), SendRequestResult.sent);
  });

  test('차단하면 피드에서 사라지고, 해제하면 다시 보인다', () {
    store().checkIn(
      spotId: 'seongsu',
      topic: '테스트',
      category: TopicCategory.other,
      stay: StayDuration.oneHour,
    );
    final target = db().feed('seongsu', DateTime.now()).first.uid;
    store().block(target);
    expect(
      db().feed('seongsu', DateTime.now()).any((c) => c.uid == target),
      isFalse,
    );
    store().unblock(target);
    expect(
      db().feed('seongsu', DateTime.now()).any((c) => c.uid == target),
      isTrue,
    );
  });

  test('7일이 지난 대화는 목록에서 빠진다', () {
    final ids = db().visibleChats(DateTime.now()).map((c) => c.id);
    expect(ids, isNot(contains('chat-old')));
    expect(ids, contains('chat-seojun'));
  });

  test('방 반경(200m) 밖에서는 맞는 PIN이어도 입장할 수 없다', () {
    const far = GeoPoint(37.5300, 127.0560); // 약 1.6km 남쪽
    expect(store().verifyCode('seongsu', '2580', at: far), isA<CodeTooFar>());
    expect(store().verifyCode('seongsu', '2580', at: null), isA<CodeTooFar>());
    expect(
      store().verifyCode('seongsu', '2580', at: seongsuFront),
      isA<CodeOk>(),
    );
  });

  test('주변 방은 거리순이고, 200m 안과 밖이 나뉜다', () {
    final nearby = db().nearby(seongsuFront);
    expect(nearby.first.$1.id, 'seongsu');
    final inRange = nearby
        .where((e) => e.$2 <= AppLimits.roomRadiusMeters)
        .map((e) => e.$1.id);
    expect(inRange, containsAll(['seongsu', 'seongsu-book']));
    expect(inRange, isNot(contains('seongsu-popup')));
    expect(nearby.map((e) => e.$1.id), isNot(contains('pangyo-conf')));
  });

  test('방을 열면 내가 개설자가 되고 PIN이 만들어진다', () {
    final id = store().createRoom(
      name: '테스트 방',
      address: '현재 위치',
      point: seongsuFront,
    );
    expect(db().isCreator(id), isTrue);
    final pin = db().spotCodes[id]!;
    expect(pin.length, AppLimits.spotCodeLength);
    store().regeneratePin(id);
    expect(db().spotCodes[id], isNot(pin));
    // 남이 연 방의 PIN은 바꿀 수 없다
    store().regeneratePin('seongsu');
    expect(db().spotCodes['seongsu'], '2580');
  });

  test('장소는 이름·주소·초성으로 찾는다', () {
    List<String> names(String q) =>
        db().searchPlaces(q, seongsuFront).map((p) => p.name).toList();
    expect(names('루프탑'), ['성수 카페거리 루프탑']);
    expect(names('ㅅㅇㅅ'), contains('서울숲 피크닉 광장'));
    expect(names('연남동'), ['연남동 북카페 골목']);
    expect(names('없는장소'), isEmpty);
  });
}
