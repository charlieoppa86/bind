import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../data/demo/demo_store.dart';

/// 방을 연 직후: 개설자에게만 입장 PIN을 보여준다.
class RoomPinScreen extends ConsumerWidget {
  const RoomPinScreen({required this.spotId, super.key});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(demoStoreProvider);
    final room = db.spot(spotId);
    final pin = db.spotCodes[spotId] ?? '';
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                PageHeader(
                  eyebrow: MetaLabel(
                    room?.name ?? '',
                    icon: Icons.place_outlined,
                  ),
                  title: '방이 열렸어요!\n입장 PIN을 알려주세요',
                  description:
                      '${AppLimits.roomRadiusMeters.round()}m 안에 있으면서 이 PIN을 아는 사람만 들어올 수 있어요. '
                      'PIN은 방을 연 나에게만 보여요.',
                ),
                const SizedBox(height: AppSpacing.sm),
                PinDigits(pin),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(demoStoreProvider.notifier)
                          .regeneratePin(spotId);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('PIN 다시 만들기'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _Tip(
                  icon: Icons.record_voice_over_outlined,
                  text: '옆자리 사람에게 말로 알려주거나, 테이블에 적어 두세요.',
                ),
                const _Tip(
                  icon: Icons.lock_outline_rounded,
                  text: '모르는 사람이 들어오는 게 걱정되면 언제든 PIN을 다시 만들 수 있어요. 이미 들어온 사람은 그대로예요.',
                ),
                const _Tip(
                  icon: Icons.visibility_outlined,
                  text: '체크인한 뒤에도 피드 위쪽 “입장 PIN”에서 다시 볼 수 있어요.',
                ),
              ],
            ),
          ),
          BottomCta(
            child: FilledButton(
              onPressed: () =>
                  context.pushReplacement(Routes.topicSetup(spotId: spotId)),
              child: const Text('내 주제 정하고 입장하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 체크인 후 개설자가 PIN을 다시 볼 때 쓰는 시트
Future<void> showRoomPinSheet(BuildContext context, String spotId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final db = ref.watch(demoStoreProvider);
        final pin = db.spotCodes[spotId] ?? '';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('입장 PIN', style: AppTypography.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${AppLimits.roomRadiusMeters.round()}m 안의 사람에게 알려주세요. 방을 연 나에게만 보여요.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PinDigits(pin, size: 56),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(demoStoreProvider.notifier).regeneratePin(spotId);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('PIN 다시 만들기'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
