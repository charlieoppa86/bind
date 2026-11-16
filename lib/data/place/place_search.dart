import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_limits.dart';
import '../../core/utils/korean_search.dart';
import '../demo/demo_seed.dart';
import '../demo/demo_store.dart';
import '../live/checkin_repository_provider.dart';
import '../live/live_mode.dart';
import '../models/place.dart';

/// 장소 검색. 실제로는 카카오 로컬 "키워드로 장소 검색"을 쓴다.
///
/// 카카오 REST 키를 앱에 넣지 않도록 Cloud Functions(`searchPlaces`)가
/// 대신 호출한다(functions/src/index.ts).
abstract interface class PlaceSearch {
  Future<List<Place>> search(String query);
}

/// Cloud Functions를 거쳐 카카오 장소 검색을 부른다.
class FunctionsPlaceSearch implements PlaceSearch {
  FunctionsPlaceSearch([FirebaseFunctions? functions])
    : _call = (functions ?? FirebaseFunctions.instanceFor(region: region))
          .httpsCallable('searchPlaces');

  /// functions/src/index.ts의 region과 같아야 한다.
  static const region = 'asia-northeast3';

  final HttpsCallable _call;

  @override
  Future<List<Place>> search(String query) async {
    final result = await _call.call<Map<String, dynamic>>({'query': query});
    final items = (result.data['places'] as List?) ?? const [];
    return [
      for (final item in items)
        Place.fromMap(Map<String, dynamic>.from(item as Map)),
    ];
  }
}

/// 데모 모드: 더미 장소 목록에서 찾는다(초성 검색 포함).
class DemoPlaceSearch implements PlaceSearch {
  const DemoPlaceSearch();

  @override
  Future<List<Place>> search(String query) async {
    // 네트워크 응답처럼 아주 잠깐 기다린다.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return [
      for (final p in DemoSeed.places)
        if (KoreanSearch.matches(p.name, query) ||
            KoreanSearch.matches(p.address, query) ||
            KoreanSearch.matches(p.category, query))
          p,
    ].take(AppLimits.placeSearchMaxResults).toList();
  }
}

/// 지금 쓰는 장소 검색. Firebase가 준비되면 main.dart에서
/// [FunctionsPlaceSearch]로 바꿔 끼운다.
final placeSearchProvider = Provider<PlaceSearch>(
  (ref) => const DemoPlaceSearch(),
);

/// 검색어별 결과. 입력이 멈춘 뒤에만 부르고(디바운스), 검색어가 바뀌면
/// 이전 요청 결과는 버린다(autoDispose).
final placeSearchResultsProvider = FutureProvider.autoDispose
    .family<List<Place>, String>((ref, query) async {
      final q = query.trim();
      if (q.length < AppLimits.placeSearchMinLength) return const [];
      await Future<void>.delayed(AppLimits.placeSearchDebounce);
      if (!ref.mounted) return const [];
      final places = await ref.read(placeSearchProvider).search(q);
      // 실제 모드: 이미 열린 장소의 "지금 n명"을 붙이려고 장소 문서를 함께 읽는다.
      if (ref.mounted && ref.read(liveModeProvider) && places.isNotEmpty) {
        try {
          final spots = await ref.read(checkinRepositoryProvider).fetchSpots([
            for (final p in places) p.id,
          ]);
          if (ref.mounted) {
            ref.read(demoStoreProvider.notifier).applySpots(spots);
          }
        } catch (e) {
          debugPrint('[BIND] 장소 인원 조회 실패: $e');
        }
      }
      return places;
    });
