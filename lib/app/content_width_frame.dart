import 'package:material_ui/material_ui.dart';

import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';

/// 넓은 화면(아이패드)에서 앱 전체를 [AppSpacing.maxContentWidth] 너비로 가운데 둔다.
///
/// `MaterialApp.builder`에서 Navigator 바깥을 감싸므로 화면·바텀시트·다이얼로그·
/// 앱 안 알림이 모두 같은 너비 안에 그려진다. 안쪽에서 읽는 `MediaQuery` 크기도
/// 이 너비로 바꿔 넣어, 화면 크기로 계산하는 위젯이 실제 그려지는 너비를 보게 한다.
/// 폰처럼 좁은 화면에서는 아무것도 바꾸지 않는다.
class ContentWidthFrame extends StatelessWidget {
  const ContentWidthFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const maxWidth = AppSpacing.maxContentWidth;
    if (media.size.width <= maxWidth) return child;
    return ColoredBox(
      color: AppColors.canvas,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
