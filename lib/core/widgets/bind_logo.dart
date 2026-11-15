import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// BIND 워드마크
class BindLogo extends StatelessWidget {
  const BindLogo({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.forum_rounded,
            color: AppColors.onPrimary,
            size: size * 0.6,
          ),
        ),
        SizedBox(
          width: size * 0.3 > AppSpacing.sm ? AppSpacing.sm : size * 0.3,
        ),
        Text(
          'BIND',
          style: AppTypography.heading.copyWith(
            fontSize: size * 0.9,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
