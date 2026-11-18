import 'package:bind_app/core/constants/app_limits.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/data/demo/demo_seed.dart';
import 'package:bind_app/data/demo/demo_store.dart';
import 'package:bind_app/data/models/place.dart';
import 'package:bind_app/data/place/place_search.dart';
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
      place: DemoSeed.places[0],
      topic: '테스트 주제',
      category: TopicCategory.dev,
    );
    expect(container.read(sessionProvider).isCheckedIn, isTrue);
    expect(db().feed('seongsu', DateTime.now()), isNotEmpty);
    expect(db().recentTopics.first.$1, '테스트 주제');
  });

  test('같은 사람에게는 대기 중 요청 1개, 무료는 하루 5번까지', () {
    store().checkIn(
      place: DemoSeed.places[2],
      topic: '테스트',
      category: TopicCategory.other,
    );
    final feed = db().feed('pangyo-conf', DateTime.now());
    expect(store().sendRequest(feed[0], '안녕하세요'), SendRequestResult.sent);
    expect(store().sendRequest(feed[0], '또 보내요'), SendRequestResult.duplicate);

    // 시드에 오늘 보낸 요청 기록이 있을 수 있으니 한도까지 채운다
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
      place: DemoSeed.places[0],
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

  test('같은 카카오 장소를 고르면 같은 장소로 묶인다', () {
    expect(db().spotByPlaceId(DemoSeed.places[0].id)?.id, 'seongsu');
    expect(db().spotByPlaceId('없는-장소'), isNull);
  });

  test('데모 장소 검색: 이름·업종·초성으로 찾는다', () async {
    const search = DemoPlaceSearch();
    List<String> names(List<Place> r) => [for (final p in r) p.name];
    expect(names(await search.search('워크')), ['성수 워크라운지']);
    expect(names(await search.search('ㅇㄴ')), contains('연남 코워킹 하우스'));
    expect(names(await search.search('카페')), contains('성수 루프탑 카페'));
    expect(await search.search('없는곳'), isEmpty);
  });

  test('처음 체크인하는 장소는 새로 열리고, 같은 장소를 고르면 같은 곳이다', () {
    final rooftop = DemoSeed.places.firstWhere((p) => p.name == '성수 루프탑 카페');
    expect(db().spotByPlaceId(rooftop.id), isNull);
    store().checkIn(
      place: rooftop,
      topic: '테스트',
      category: TopicCategory.other,
    );
    final spot = db().spotByPlaceId(rooftop.id)!;
    expect(spot.name, '성수 루프탑 카페');
    expect(spot.address, rooftop.address);
    expect(db().isCreator(spot.id), isTrue);
    expect(db().recentSpots.first.id, spot.id);
    expect(db().myCheckins(DateTime.now()).single.spotId, spot.id);
    // 최근 간 장소 칩에서 다시 고르면 같은 카카오 장소다
    expect(spot.toPlace(), rooftop);
  });

  test('체류 시간 제한이 없어 체크아웃 전까지 카드가 남는다', () {
    store().checkIn(
      place: DemoSeed.places[0],
      topic: '테스트',
      category: TopicCategory.other,
    );
    final later = DateTime.now().add(const Duration(days: 1));
    expect(db().myCheckins(later), hasLength(1));
    store().checkOut();
    expect(db().myCheckins(DateTime.now()), isEmpty);
  });

  test('하는 일을 기타로 고르고 직접 입력하면 그 글자가 카드에 보인다', () {
    store().updateProfile('지후', JobTag.other, jobCustom: ' 바리스타 ');
    expect(db().me!.jobLabel, '바리스타');
    store().checkIn(
      place: DemoSeed.places[0],
      topic: '테스트',
      category: TopicCategory.other,
    );
    expect(db().myCheckins(DateTime.now()).single.jobLabel, '바리스타');
    // 기타가 아닌 태그로 바꾸면 직접 입력값은 지워진다
    store().updateProfile('지후', JobTag.chef, jobCustom: '바리스타');
    expect(db().me!.jobCustom, isNull);
    expect(db().me!.jobLabel, '셰프·요리');
  });

  test('키워드는 24개, 기타를 고르면 직접 입력한 키워드가 카드에 보인다', () {
    expect(TopicCategory.values, hasLength(24));
    store().checkIn(
      place: DemoSeed.places[0],
      topic: '사진 같이 찍어요',
      category: TopicCategory.other,
      categoryCustom: ' 사진 ',
    );
    final card = db().myCheckins(DateTime.now()).single;
    expect(card.keywordLabel, '사진');

    // 기타가 아닌 키워드로 바꾸면 직접 입력값은 지워진다
    store().updateTopic(
      card.id,
      '사진 같이 찍어요',
      TopicCategory.culture,
      categoryCustom: '사진',
    );
    final updated = db().myCheckins(DateTime.now()).single;
    expect(updated.categoryCustom, isNull);
    expect(updated.keywordLabel, '전시·공연');
  });
}
