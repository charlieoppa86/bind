import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/enums.dart';

/// 카드·요청 상세·대화방의 신고/차단 메뉴(US-010: 두 번 눌러 신고·차단).
class SafetyMenuButton extends StatelessWidget {
  const SafetyMenuButton({
    required this.targetUid,
    required this.source,
    this.onBlocked,
    this.iconColor = AppColors.secondary,
    super.key,
  });

  final String targetUid;
  final ReportSource source;

  /// 차단(또는 신고하며 차단)한 뒤 호출. 화면을 닫는 등 후처리.
  final VoidCallback? onBlocked;
  final Color iconColor;

  Future<void> _report(BuildContext context) async {
    final result = await context.push<ReportOutcome>(
      Routes.report(targetUid, source: source.name),
    );
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.blocked ? '신고하고 차단했어요. 이제 이 사람이 보이지 않아요.' : '신고가 접수됐어요.',
        ),
      ),
    );
    if (result.blocked) onBlocked?.call();
  }

  Future<void> _block(BuildContext context) async {
    final ok = await context.push<bool>(Routes.block(targetUid));
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('차단했어요. 마이 > 차단 목록에서 해제할 수 있어요.')),
    );
    onBlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '신고·차단',
      icon: Icon(Icons.more_vert, color: iconColor, size: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.menu),
      ),
      color: AppColors.canvas,
      onSelected: (v) => v == 'report' ? _report(context) : _block(context),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'report', child: Text('신고하기')),
        PopupMenuItem(value: 'block', child: Text('차단하기')),
      ],
    );
  }
}

/// 신고 시트 결과
class ReportOutcome {
  const ReportOutcome({required this.blocked});
  final bool blocked;
}
