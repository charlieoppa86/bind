import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'in_app_notice.dart';

/// 화면 위쪽에 푸시 알림처럼 잠깐 나타나는 앱 안 알림.
/// 하단 버튼을 가리지 않도록 스낵바 대신 위에 띄운다.
class NoticeBannerHost extends ConsumerStatefulWidget {
  const NoticeBannerHost({
    required this.child,
    required this.onOpen,
    super.key,
  });

  final Widget child;

  /// 알림을 눌렀을 때 이동
  final void Function(String route) onOpen;

  @override
  ConsumerState<NoticeBannerHost> createState() => _NoticeBannerHostState();
}

class _NoticeBannerHostState extends ConsumerState<NoticeBannerHost> {
  static const _visibleFor = Duration(seconds: 4);

  InAppNotice? _notice;
  bool _visible = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(InAppNotice notice) {
    _timer?.cancel();
    setState(() {
      _notice = notice;
      _visible = true;
    });
    _timer = Timer(_visibleFor, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inAppNoticeProvider, (_, n) {
      if (n != null) _show(n);
    });
    final notice = _notice;
    final top = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: _visible ? top : -120,
          child: notice == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) < 0) _hide();
                  },
                  child: Material(
                    color: AppColors.elevated,
                    elevation: 6,
                    shadowColor: AppColors.shadow,
                    borderRadius: BorderRadius.circular(AppRadius.menu),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.menu),
                      onTap: notice.route == null
                          ? _hide
                          : () {
                              _hide();
                              widget.onOpen(notice.route!);
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                notice.message,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.heading,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (notice.route != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                notice.actionLabel ?? '보기',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
