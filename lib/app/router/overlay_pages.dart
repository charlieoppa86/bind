import 'package:material_ui/material_ui.dart';

/// IA에서 "바텀시트"로 표시하는 라우트용 Page.
class BottomSheetPage<T> extends Page<T> {
  const BottomSheetPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => child,
  );
}

/// IA에서 "다이얼로그(POP)"로 표시하는 라우트용 Page.
class DialogPage<T> extends Page<T> {
  const DialogPage({
    required this.child,
    this.barrierDismissible = true,
    super.key,
    super.name,
  });

  final Widget child;
  final bool barrierDismissible;

  @override
  Route<T> createRoute(BuildContext context) => DialogRoute<T>(
    context: context,
    settings: this,
    barrierDismissible: barrierDismissible,
    builder: (_) => child,
  );
}
