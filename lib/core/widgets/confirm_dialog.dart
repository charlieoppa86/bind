import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 제목 + 설명 + 나란한 두 버튼(취소 / 확인) 다이얼로그.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.onCancel,
    this.message,
    this.cancelLabel = '취소',
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final VoidCallback onConfirm;

  /// null이면 확인 버튼 하나만 보여 준다(알림용).
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.page + 4,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.page),
            Row(
              children: [
                if (onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: destructive ? AppColors.error : null,
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// [ConfirmDialog]를 띄우고 확인을 눌렀는지 돌려준다.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = '취소',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      onConfirm: () => Navigator.pop(c, true),
      onCancel: () => Navigator.pop(c, false),
    ),
  );
  return ok ?? false;
}

/// 확인 버튼 하나만 있는 알림 다이얼로그.
Future<void> showNotice(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
}) => showDialog<void>(
  context: context,
  builder: (c) => ConfirmDialog(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    onConfirm: () => Navigator.pop(c),
  ),
);
