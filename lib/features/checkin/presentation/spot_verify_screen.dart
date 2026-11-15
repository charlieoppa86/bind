import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/location/location.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../data/demo/demo_store.dart';

/// 체크인 > 주변 방 > 입장 PIN (US-004). 방 반경 안에서 개설자에게 받은 PIN을 입력한다.
class SpotVerifyScreen extends ConsumerStatefulWidget {
  const SpotVerifyScreen({required this.spotId, super.key});

  final String spotId;

  @override
  ConsumerState<SpotVerifyScreen> createState() => _SpotVerifyScreenState();
}

class _SpotVerifyScreenState extends ConsumerState<SpotVerifyScreen> {
  final _dots = GlobalKey<PinDotsState>();
  String _pin = '';
  String? _error;
  bool _checking = false;

  void _digit(String d) {
    if (_checking || _pin.length >= AppLimits.spotCodeLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == AppLimits.spotCodeLength) _submit();
  }

  void _backspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    _checking = true;
    // 마지막 칸이 채워지는 것을 잠깐 보여준다.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    // TODO(firebase): Cloud Functions callable로 PIN 검증
    final result = ref
        .read(demoStoreProvider.notifier)
        .verifyCode(widget.spotId, _pin, at: ref.read(locationProvider).point);
    switch (result) {
      case CodeOk():
        HapticFeedback.mediumImpact();
        await context.push(Routes.topicSetup(spotId: widget.spotId));
        if (mounted) setState(() => _pin = '');
      case CodeWrong(:final attemptsLeft):
        _dots.currentState?.shake();
        setState(() {
          _error = 'PIN이 맞지 않아요. $attemptsLeft번 더 시도할 수 있어요.';
          _pin = '';
        });
      case CodeTooFar(:final meters):
        _dots.currentState?.shake();
        setState(() {
          _error = meters.isFinite
              ? '방에서 ${formatDistance(meters)} 떨어져 있어요. ${AppLimits.roomRadiusMeters.round()}m 안에서만 입장할 수 있어요.'
              : '위치를 확인할 수 없어요. 위치를 켜고 다시 시도해 주세요.';
          _pin = '';
        });
      case CodeLocked():
        _dots.currentState?.shake();
        setState(() {
          _error = null;
          _pin = '';
        });
    }
    _checking = false;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final spot = db.spot(widget.spotId);
    final here = ref.watch(locationProvider).point;
    final distance = spot == null || here == null
        ? null
        : here.distanceTo(GeoPoint(spot.latitude, spot.longitude));
    final creator = db.user(spot?.creatorUid ?? '')?.nickname;
    final (_, lockedUntil) = db.codeAttempts[widget.spotId] ?? (0, null);
    final now = DateTime.now();
    final locked = lockedUntil != null && now.isBefore(lockedUntil);
    final lockMinutes = locked ? lockedUntil.difference(now).inMinutes + 1 : 0;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              eyebrow: MetaLabel(
                spot?.name ?? '',
                icon: spot?.isEvent ?? false
                    ? Icons.celebration_outlined
                    : Icons.apartment_rounded,
              ),
              title: '입장 PIN ${AppLimits.spotCodeLength}자리를\n입력해 주세요',
              description: creator == null
                  ? '방을 연 사람에게 PIN을 물어보세요.'
                  : '방을 연 $creator님에게 PIN을 물어보세요.\n${distance == null ? '' : '여기서 ${formatDistance(distance)} 떨어진 방이에요.'}',
            ),
            PinDots(
              key: _dots,
              length: AppLimits.spotCodeLength,
              filled: _pin.length,
              error: _error != null && _pin.isEmpty,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: locked
                    ? Text(
                        '${AppLimits.spotCodeMaxAttempts}번 틀려서 $lockMinutes분 동안 PIN 입력이 막혔어요.\n방을 연 사람에게 새 PIN을 받아 보세요.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : _error != null
                    ? Text(
                        _error!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : null,
              ),
            ),
            const Spacer(),
            if (kDebugMode)
              Text(
                textAlign: TextAlign.center,
                '개발용: 개설자 PIN은 ${db.spotCodes[widget.spotId]}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            PinPad(enabled: !locked, onDigit: _digit, onBackspace: _backspace),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
