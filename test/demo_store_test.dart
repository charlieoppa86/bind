import 'package:bind_app/core/constants/app_limits.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:bind_app/features/session/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('체크인하면 세션이 바뀌고 피드에 다른 사람 카드가 보인다', () {
    store().checkIn(
      placeName: '성수 워크라운지',
      topic: '테스트 주제',
      category: TopicCategory.dev,
    );
    expect(container.read(sessionProvider).isCheckedIn, isTrue);
    expect(db().feed('seongsu', DateTime.now()), isNotEmpty);
    expect(db().recentTopics.first.$1, '테스트 주제');
  });

  test('같은 사람에게는 대기 중 신청 1개, 무료는 하루 5번까지', () {
    store().checkIn(
      placeName: '판교 프로덕트 컨퍼런스',
      topic: '테스트',
      category: TopicCategory.other,
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
      placeName: '성수 워크라운지',
      topic: '테스트',
      category: TopicCategory.other,
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

  test('장소 이름은 띄어쓰기·대소문자를 무시하고 같은 장소로 묶인다', () {
    expect(db().spotByName('성수워크라운지')?.id, 'seongsu');
    expect(db().spotByName('  성수 워크라운지 ')?.id, 'seongsu');
    expect(db().spotByName('없는 장소'), isNull);
  });

  test('입력하는 동안 이미 있는 장소를 추천한다(초성 포함), 사람 많은 순', () {
    final now = DateTime.now();
    List<String> names(String q) =>
        db().suggestSpots(q, now).map((s) => s.name).toList();
    expect(names('워크'), ['성수 워크라운지']);
    expect(names('ㅇㄴ'), contains('연남 코워킹 하우스'));
    expect(names('없는'), isEmpty);
  });

  test('처음 입력한 장소는 새로 열리고, 같은 이름으로 다시 오면 같은 장소다', () {
    store().checkIn(
      placeName: '성수 카페 루프탑',
      topic: '테스트',
      category: TopicCategory.other,
    );
    final spot = db().spotByName('성수카페루프탑')!;
    expect(db().isCreator(spot.id), isTrue);
    expect(db().recentSpots.first.id, spot.id);
    expect(db().myCheckins(DateTime.now()).single.spotId, spot.id);
  });

  test('체류 시간 제한이 없어 체크아웃 전까지 카드가 남는다', () {
    store().checkIn(
      placeName: '성수 워크라운지',
      topic: '테스트',
      category: TopicCategory.other,
    );
    final later = DateTime.now().add(const Duration(days: 1));
    expect(db().myCheckins(later), hasLength(1));
    store().checkOut();
    expect(db().myCheckins(DateTime.now()), isEmpty);
  });
}
