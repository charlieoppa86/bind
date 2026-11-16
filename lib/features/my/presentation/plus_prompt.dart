import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/widgets/confirm_dialog.dart';

/// BIND+ 안내 POP (US-019). 주제 설정·대화 요청 두 곳에서 뜨고, 이동 대상은 마이 > BIND+.
Future<void> showPlusPrompt(
  BuildContext context, {
  required String reason,
}) async {
  final go = await showConfirm(
    context,
    title: 'BIND+로 더 많이 대화해 보세요',
    message:
        '$reason\nBIND+는 주제를 ${AppLimits.plusActiveTopics}개까지 동시에 올리고, '
        '하루 요청을 무제한으로 보낼 수 있어요.',
    cancelLabel: '다음에',
    confirmLabel: '알아보기',
  );
  if (go && context.mounted) context.push(Routes.myPlus);
}
