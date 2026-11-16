import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 안에서 띄우는 알림(스낵바). 푸시 알림이 붙기 전까지
/// 신청 도착·수락·만료·새 메시지를 이것으로 알려준다.
class InAppNotice {
  const InAppNotice(this.message, {this.actionLabel, this.route});

  final String message;
  final String? actionLabel;

  /// 액션을 누르면 이동할 경로(`Routes`)
  final String? route;
}

class InAppNoticeController extends Notifier<InAppNotice?> {
  @override
  InAppNotice? build() => null;

  void show(InAppNotice notice) => state = notice;
}

final inAppNoticeProvider =
    NotifierProvider<InAppNoticeController, InAppNotice?>(
      InAppNoticeController.new,
    );
