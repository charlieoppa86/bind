import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_limits.dart';
import '../../../core/widgets/confirm_dialog.dart';

/// BIND+는 출시 후 실제 결제를 붙일 예정이라, 지금은 "준비 중" 안내만 띄운다.
/// 결제를 붙이면 [showPlusComingSoon] 대신 마이 > BIND+(`Routes.myPlus`)로 보낸다.
Future<void> showPlusComingSoon(BuildContext context) => showNotice(
  context,
  title: 'BIND+는 준비 중입니다.',
  message: '주제를 여러 개 올리고 하루 요청을 무제한으로 보내는 기능을 준비하고 있어요. 조금만 기다려 주세요!',
);

/// BIND+ 안내 POP (US-019). 하루 요청 횟수·동시 주제 수에 걸렸을 때 뜬다.
/// 지금은 결제 전이라 이유와 함께 "준비 중"을 알린다.
Future<void> showPlusPrompt(BuildContext context, {required String reason}) =>
    showNotice(
      context,
      title: 'BIND+는 준비 중입니다.',
      message:
          '$reason\nBIND+가 나오면 주제를 ${AppLimits.plusActiveTopics}개까지 동시에 올리고, '
          '하루 요청을 무제한으로 보낼 수 있어요.',
    );
