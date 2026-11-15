import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/topic_content.dart';
import '../../../core/utils/time_format.dart';
import '../../../data/demo/demo_store.dart';

/// 마이 > 마이 > 동의 내역 (US-003 AC3)
class ConsentHistoryScreen extends ConsumerWidget {
  const ConsentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = ref.watch(demoStoreProvider).me?.consentedAt;
    return Scaffold(
      appBar: AppBar(title: const Text('동의 내역')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            at == null
                ? ''
                : '${TimeFormat.fullDate(at)} ${TimeFormat.clock(at)}에 동의했어요',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Item(text: '만 ${AppLimits.minimumAge}세 이상이에요'),
          for (final rule in communityRules) _Item(text: rule),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.bodyLarge)),
        ],
      ),
    );
  }
}
