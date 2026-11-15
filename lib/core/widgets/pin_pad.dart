import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// 숫자 PIN 입력 표시. 틀리면 [shakeKey]로 흔든다.
class PinDots extends StatefulWidget {
  const PinDots({
    required this.length,
    required this.filled,
    this.error = false,
    super.key,
  });

  final int length;
  final int filled;
  final bool error;

  @override
  State<PinDots> createState() => PinDotsState();
}

class PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// 틀렸을 때 좌우로 흔든다.
  void shake() {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        // 감쇠 사인파
        final dx = 12 * (1 - t) * math.sin(t * math.pi * 6);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 52,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: widget.error
                      ? AppColors.error
                      : i == widget.filled
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                scale: i < widget.filled ? 1 : 0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: widget.error ? AppColors.error : AppColors.heading,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 화면 하단 숫자 키패드(시스템 키보드 대신)
class PinPad extends StatelessWidget {
  const PinPad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
      child: _PadKey(
        enabled: enabled,
        onTap: onTap ?? () => onDigit(label),
        child:
            child ??
            Text(
              label,
              style: AppTypography.display.copyWith(
                fontWeight: FontWeight.w500,
                color: enabled ? AppColors.heading : AppColors.tertiary,
              ),
            ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(children: [for (final d in row) key(d)]),
          Row(
            children: [
              const Expanded(child: SizedBox(height: 64)),
              key('0'),
              key(
                '지우기',
                onTap: onBackspace,
                child: Icon(
                  Icons.backspace_outlined,
                  semanticLabel: '지우기',
                  color: enabled ? AppColors.heading : AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatefulWidget {
  const _PadKey({
    required this.child,
    required this.onTap,
    required this.enabled,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap();
            }
          : null,
      child: SizedBox(
        height: 64,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 64,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _down ? AppColors.fill : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 개설자에게 보여주는 PIN 숫자 칸
class PinDigits extends StatelessWidget {
  const PinDigits(this.pin, {this.size = 64, super.key});

  final String pin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final d in pin.split(''))
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Container(
              key: ValueKey('$pin-$d'),
              width: size * 0.85,
              height: size,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                d,
                style: AppTypography.display.copyWith(
                  fontSize: size * 0.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
