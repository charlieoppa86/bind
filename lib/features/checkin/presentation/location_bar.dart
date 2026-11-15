import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/location/location.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_seed.dart';

/// "현재 위치 기준 · 반경 200m" 표시 + 새로고침.
/// 개발 빌드에서는 눌러서 가상 위치를 고를 수 있다.
class LocationBar extends ConsumerWidget {
  const LocationBar({super.key});

  Future<void> _pickSimulated(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<(String, GeoPoint)?>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Text('개발용: 위치 바꾸기', style: AppTypography.title),
            ),
            for (final (name, lat, lng) in DemoSeed.locationPresets)
              ListRow(
                title: name,
                showChevron: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.md,
                ),
                onTap: () => Navigator.pop(c, (name, GeoPoint(lat, lng))),
              ),
            ListRow(
              title: '기기 위치 사용',
              subtitle: '에뮬레이터는 Extended controls > Location에서 바꿀 수 있어요',
              showChevron: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.md,
              ),
              onTap: () => Navigator.pop(c, ('', const GeoPoint(0, 0))),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final controller = ref.read(locationProvider.notifier);
    if (picked.$1.isEmpty) {
      await controller.simulate(null);
    } else {
      await controller.simulate(picked.$2, label: picked.$1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locationProvider);
    final simulated = loc.simulatedLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Pressable(
        onTap: kDebugMode ? () => _pickSimulated(context, ref) : null,
        color: AppColors.fill,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.my_location_rounded,
                size: 18,
                color: loc.isReady ? AppColors.primary : AppColors.tertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  simulated != null
                      ? '개발용 위치: $simulated'
                      : '현재 위치 기준 · 반경 ${AppLimits.roomRadiusMeters.round()}m',
                  style: AppTypography.body.copyWith(
                    color: AppColors.body,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (kDebugMode)
                const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.secondary,
                ),
              IconButton(
                tooltip: '위치 새로고침',
                onPressed: loc.status == LocationStatus.loading
                    ? null
                    : () => ref
                          .read(locationProvider.notifier)
                          .refresh(request: true),
                icon: loc.status == LocationStatus.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.secondary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
