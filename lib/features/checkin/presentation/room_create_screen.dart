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
import '../../../data/demo/demo_store.dart';
import 'location_bar.dart';

/// 체크인 > 새 방 열기: 장소를 정하면 내가 개설자가 되고 입장 PIN이 만들어진다.
///
/// 지금 위치에서 [AppLimits.roomRadiusMeters] 안의 장소에만 열 수 있다.
class RoomCreateScreen extends ConsumerStatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  ConsumerState<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends ConsumerState<RoomCreateScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirm({
    required String suggestedName,
    required String address,
    required GeoPoint point,
  }) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NameSheet(initial: suggestedName, address: address),
    );
    if (name == null || !mounted) return;
    HapticFeedback.mediumImpact();
    final id = ref
        .read(demoStoreProvider.notifier)
        .createRoom(name: name, address: address, point: point);
    context.pushReplacement(Routes.roomPin(id));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final loc = ref.watch(locationProvider);
    final radius = AppLimits.roomRadiusMeters.round();
    final query = _search.text.trim();
    final places = loc.hasPoint
        ? db
              .searchPlaces(query, loc.point!)
              .where(
                (p) =>
                    query.isNotEmpty ||
                    p.distance <= AppLimits.nearbyListMeters,
              )
              .toList()
        : const <NearbyPlace>[];

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          PageHeader(
            title: '어디에 방을 열까요?',
            description:
                '지금 위치에서 ${radius}m 안의 장소에만 열 수 있어요.\n방을 열면 입장 PIN이 만들어져요.',
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.lg,
            ),
          ),
          const LocationBar(),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page - 4,
            ),
            child: TextField(
              controller: _search,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.heading),
              decoration: const InputDecoration(
                hintText: '장소 이름, 주소 (예: 루프탑, 성수동)',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.secondary,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (!loc.hasPoint)
            const EmptyState(
              icon: Icons.location_off_outlined,
              title: '위치를 확인할 수 없어요',
              message: '위치를 켜야 지금 있는 곳에 방을 열 수 있어요.',
            )
          else ...[
            if (query.isEmpty) ...[
              const SectionLabel('지금 있는 곳'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: ListRow(
                  leading: const IconTile(
                    Icons.my_location_rounded,
                    size: 48,
                    color: AppColors.primarySoft,
                    iconColor: AppColors.primary,
                  ),
                  title: '현재 위치에 방 열기',
                  titleStyle: AppTypography.subtitle,
                  subtitle: '장소 이름을 직접 정해요',
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md - 2,
                  ),
                  onTap: () => _confirm(
                    suggestedName: '',
                    address: '현재 위치',
                    point: loc.point!,
                  ),
                ),
              ),
            ],
            SectionLabel(query.isEmpty ? '근처 장소' : '검색 결과 ${places.length}'),
            if (places.isEmpty)
              EmptyState(
                icon: Icons.search_off_rounded,
                title: '‘$query’ 장소를 찾지 못했어요',
                message: '현재 위치에 방을 열고 이름을 직접 정할 수 있어요.',
              ),
            for (final p in places)
              Opacity(
                opacity: p.inRange ? 1 : 0.45,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: ListRow(
                    leading: IconTile(
                      Icons.place_outlined,
                      size: 48,
                      iconColor: p.inRange
                          ? AppColors.heading
                          : AppColors.secondary,
                    ),
                    title: p.name,
                    titleStyle: AppTypography.subtitle,
                    subtitle: '${formatDistance(p.distance)} · ${p.address}',
                    showChevron: false,
                    trailing: p.inRange
                        ? null
                        : Text('${radius}m 밖', style: AppTypography.caption),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md - 2,
                    ),
                    onTap: p.inRange
                        ? () => _confirm(
                            suggestedName: p.name,
                            address: p.address,
                            point: p.point,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 방 이름 확인 시트
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial, required this.address});

  final String initial;
  final String address;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().length >= AppLimits.roomNameMin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('방 이름을 정해 주세요', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '주변 사람들이 목록에서 이 이름을 보고 찾아와요.',
              style: AppTypography.body.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              autofocus: widget.initial.isEmpty,
              maxLength: AppLimits.roomNameMax,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.heading,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(hintText: '예) 성수 카페 2층 창가'),
              onChanged: (_) => setState(() {}),
            ),
            MetaLabel(widget.address, icon: Icons.place_outlined),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(context, _name.text.trim())
                  : null,
              child: const Text('방 열고 PIN 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}
