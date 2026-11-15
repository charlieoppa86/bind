import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 앱 테마.
///
/// 색·글꼴은 docs/DESIGN.md 토큰을 따르고, 컨트롤 모양은 토스류 모바일 앱 패턴을 참고했다.
/// - 테두리 대신 회색 면(fill)으로 입력칸·보조 버튼·칩을 구분한다.
/// - 큰 CTA는 56px, 라운드 16. 바텀시트 상단 라운드 24.
/// - 눌림은 #171719 state layer(+ 위젯 단의 살짝 줄어드는 스케일)로 표현한다.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.canvas,
      onSurface: AppColors.heading,
      onSurfaceVariant: AppColors.secondary,
      surfaceContainerLow: AppColors.subtleSurface,
      outline: AppColors.controlBorder,
      outlineVariant: AppColors.hairline,
      error: AppColors.error,
    );

    WidgetStateProperty<Color?> overlay(double hover, double pressed) =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.stateLayer.withValues(alpha: pressed);
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.stateLayer.withValues(alpha: hover);
          }
          return null;
        });

    const ctaShape = WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
      ),
    );
    const ctaSize = WidgetStatePropertyAll(Size(64, AppSpacing.ctaHeight));
    const ctaPadding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
    const inputRadius = BorderRadius.all(Radius.circular(AppRadius.card));

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.heading,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.supportingTitle,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      // 주 CTA: 파란 면, 56px
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: ctaSize,
          padding: ctaPadding,
          shape: ctaShape,
          textStyle: const WidgetStatePropertyAll(AppTypography.button),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.fill
                : AppColors.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.tertiary
                : AppColors.onPrimary,
          ),
          overlayColor: overlay(0.075, 0.18),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      // 보조 CTA: 회색 면, 테두리 없음
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: ctaSize,
          padding: ctaPadding,
          shape: ctaShape,
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: const WidgetStatePropertyAll(AppColors.fill),
          textStyle: const WidgetStatePropertyAll(AppTypography.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.tertiary
                : AppColors.heading,
          ),
          overlayColor: overlay(0.0375, 0.09),
        ),
      ),
      // 텍스트 액션: primary 라벨
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppRadius.control),
              ),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.tertiary
                : AppColors.primary,
          ),
          overlayColor: overlay(0.0375, 0.09),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(overlayColor: overlay(0.0375, 0.09)),
      ),
      // 칩: 알약 모양, 회색 면 → 선택 시 파란 면
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fill,
        selectedColor: AppColors.primary,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: AppTypography.body.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.body,
        ),
        secondaryLabelStyle: AppTypography.body.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      // 입력칸: 회색 면, 포커스 시 파란 테두리
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.tertiary),
        helperStyle: AppTypography.caption,
        errorStyle: AppTypography.caption.copyWith(color: AppColors.error),
        counterStyle: AppTypography.caption,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 16,
        ),
        border: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionHandleColor: AppColors.primary,
      ),
      // 카드: 그림자·테두리 없는 흰 면(회색 배경 위에 올린다)
      cardTheme: const CardThemeData(
        color: AppColors.canvas,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.section)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
        minVerticalPadding: 14,
        iconColor: AppColors.heading,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.hairline,
        dragHandleSize: Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.section)),
        ),
        titleTextStyle: AppTypography.title,
        contentTextStyle: AppTypography.bodyLarge,
        actionsPadding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: AppColors.heading.withValues(alpha: 0.2),
        textStyle: AppTypography.bodyLarge.copyWith(color: AppColors.heading),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.menu)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppTypography.caption.copyWith(
            fontSize: 11,
            color: s.contains(WidgetState.selected)
                ? AppColors.heading
                : AppColors.tertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 26,
            color: s.contains(WidgetState.selected)
                ? AppColors.heading
                : AppColors.tertiary,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.heading,
        unselectedLabelColor: AppColors.tertiary,
        labelStyle: AppTypography.supportingTitle,
        unselectedLabelStyle: AppTypography.supportingTitle,
        indicatorColor: AppColors.heading,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.hairline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.onPrimary),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.hairline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.tertiary, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.tertiary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.heading,
        linearTrackColor: AppColors.fill,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.error,
        textColor: AppColors.onPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.body,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.menu)),
        ),
      ),
    );
  }
}
