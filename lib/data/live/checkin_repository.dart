import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/enums.dart';
import '../models/app_user.dart';
import '../models/checkin.dart';
import '../models/place.dart';
import '../models/spot.dart';

/// 장소(`spots/{placeId}`)와 체크인(`checkins/{id}`) Firestore 저장소.
///
/// - 장소 문서 id는 카카오 장소 ID라서 "찾기 또는 만들기"가 한 번에 된다.
/// - 장소의 지금 인원(`activeCount`)은 Cloud Functions가 체크인 변화에 맞춰 갱신한다.
/// - 체크인 카드에는 닉네임·하는 일을 복사해 둔다(피드에서 사용자 문서를 다시 읽지 않도록).
class CheckinRepository {
  CheckinRepository([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _spots =>
      _db.collection('spots');
  CollectionReference<Map<String, dynamic>> get _checkins =>
      _db.collection('checkins');

  /// 내 체크인 중 체크아웃 전인 것
  Stream<List<Checkin>> watchMyActive(String uid) => _checkins
      .where('uid', isEqualTo: uid)
      .where('checkedOutAt', isNull: true)
      .snapshots()
      .map(_toCheckins);

  /// 한 장소에서 체크아웃 전인 모든 카드(내 것 포함)
  Stream<List<Checkin>> watchSpotActive(String spotId) => _checkins
      .where('spotId', isEqualTo: spotId)
      .where('checkedOutAt', isNull: true)
      .snapshots()
      .map(_toCheckins);

  Stream<Spot?> watchSpot(String spotId) => _spots
      .doc(spotId)
      .snapshots()
      .map((s) => s.data() == null ? null : Spot.fromMap(s.id, s.data()!));

  /// 검색 결과에 "지금 n명"을 붙이기 위해 열려 있는 장소만 한 번에 읽는다.
  Future<List<Spot>> fetchSpots(List<String> placeIds) async {
    if (placeIds.isEmpty) return const [];
    final out = <Spot>[];
    // whereIn은 한 번에 30개까지
    for (var i = 0; i < placeIds.length; i += 30) {
      final chunk = placeIds.sublist(
        i,
        i + 30 > placeIds.length ? placeIds.length : i + 30,
      );
      final snap = await _spots
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      out.addAll([for (final d in snap.docs) Spot.fromMap(d.id, d.data())]);
    }
    return out;
  }

  /// 장소가 없으면 만들고, 그 장소에 내 주제 카드를 올린다(한 번에).
  /// [me]의 연령대·성별은 카드에 넣고, 다음 체크인에 미리 채우도록 프로필에도 남긴다.
  Future<void> checkIn({
    required String uid,
    required AppUser me,
    required Place place,
    required String topic,
    required TopicCategory category,
    String? categoryCustom,
    bool openGroupChat = false,
  }) async {
    final spotRef = _spots.doc(place.id);
    await _db.runTransaction((tx) async {
      final spot = await tx.get(spotRef);
      if (!spot.exists) {
        tx.set(spotRef, {
          'placeId': place.id,
          'name': place.name,
          'address': place.address,
          'category': place.category,
          'lat': place.lat,
          'lng': place.lng,
          'creatorUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(
        _checkins.doc(),
        _newCard(
          uid,
          me,
          place.id,
          topic,
          category,
          categoryCustom,
          openGroupChat: openGroupChat,
        ),
      );
      tx.update(_db.collection('users').doc(uid), {
        'ageBand': me.ageBand?.name,
        'gender': me.gender?.name,
      });
    });
  }

  /// 같은 장소에 주제 하나 더 올리기(BIND+)
  Future<void> addTopic({
    required String uid,
    required AppUser me,
    required String spotId,
    required String topic,
    required TopicCategory category,
    String? categoryCustom,
  }) =>
      _checkins.add(_newCard(uid, me, spotId, topic, category, categoryCustom));

  Future<void> updateTopic(
    String checkinId,
    String topic,
    TopicCategory category, {
    String? categoryCustom,
  }) => _checkins.doc(checkinId).update({
    'topic': topic,
    'category': category.name,
    'categoryCustom': _customFor(category, categoryCustom),
  });

  /// 기타일 때만 직접 입력한 키워드를 저장한다.
  static String? _customFor(TopicCategory category, String? custom) =>
      category == TopicCategory.other && (custom?.trim().isNotEmpty ?? false)
      ? custom!.trim()
      : null;

  /// 카드 하나 내리기
  Future<void> checkOutOne(String checkinId) =>
      _checkins.doc(checkinId).update({
        'checkedOutAt': FieldValue.serverTimestamp(),
        'notifyWhenSomeoneArrives': false,
      });

  /// 내 카드 모두 내리기(체크아웃)
  Future<void> checkOutAll(Iterable<String> checkinIds) {
    final batch = _db.batch();
    for (final id in checkinIds) {
      batch.update(_checkins.doc(id), {
        'checkedOutAt': FieldValue.serverTimestamp(),
        'notifyWhenSomeoneArrives': false,
      });
    }
    return batch.commit();
  }

  Future<void> setArrivalNotify(Iterable<String> checkinIds, bool on) {
    final batch = _db.batch();
    for (final id in checkinIds) {
      batch.update(_checkins.doc(id), {'notifyWhenSomeoneArrives': on});
    }
    return batch.commit();
  }

  /// 프로필을 바꾸면 올려 둔 카드의 닉네임·하는 일도 바꾼다.
  Future<void> updateCardsProfile(Iterable<String> checkinIds, AppUser me) {
    final batch = _db.batch();
    for (final id in checkinIds) {
      batch.update(_checkins.doc(id), {
        'nickname': me.nickname,
        'jobTag': me.jobTag.name,
        'jobCustom': me.jobCustom,
      });
    }
    return batch.commit();
  }

  Map<String, dynamic> _newCard(
    String uid,
    AppUser me,
    String spotId,
    String topic,
    TopicCategory category,
    String? categoryCustom, {
    bool openGroupChat = false,
  }) => {
    'uid': uid,
    'spotId': spotId,
    'nickname': me.nickname,
    'jobTag': me.jobTag.name,
    'jobCustom': me.jobCustom,
    'topic': topic,
    'category': category.name,
    'categoryCustom': _customFor(category, categoryCustom),
    'startedAt': FieldValue.serverTimestamp(),
    'checkedOutAt': null,
    'hasTrustBadge': me.hasTrustBadge,
    'notifyWhenSomeoneArrives': false,
    // true면 서버(onCheckinWritten)가 그룹 채팅방을 만들고 groupChatId를 적는다.
    'openGroupChat': openGroupChat,
    // 카드에 보이는 연령대·성별(체크인 때 필수로 고른 값)
    'ageBand': me.ageBand?.name,
    'gender': me.gender?.name,
  };

  static List<Checkin> _toCheckins(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs) Checkin.fromMap(d.id, d.data()),
  ];
}
