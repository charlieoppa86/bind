import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/demo/demo_store.dart';

/// 글로벌 > 차단 확인 (다이얼로그, US-010)
class BlockConfirmDialog extends ConsumerWidget {
  const BlockConfirmDialog({required this.targetId, super.key});

  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname =
        ref.watch(demoStoreProvider).user(targetId)?.nickname ?? '이 사용자';
    return ConfirmDialog(
      title: '$nickname님을 차단할까요?',
      message: '카드·신청·대화가 더 이상 보이지 않아요.\n상대에게는 알리지 않아요.',
      confirmLabel: '차단',
      destructive: true,
      onCancel: () => context.pop(false),
      onConfirm: () {
        // TODO(firebase): users/{myUid}/blocks/{targetId} 생성
        ref.read(demoStoreProvider.notifier).block(targetId);
        context.pop(true);
      },
    );
  }
}
