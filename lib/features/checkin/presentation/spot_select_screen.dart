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
import '../../../data/models/spot.dart';
import 'location_bar.dart';

/// 체크인 > 내 주변 방 (US-004). 체크인 전 홈.
///
/// 현재 위치 반경 [AppLimits.roomRadiusMeters] 안에 열린 방에만 입장할 수 있다.
/// 입장하려면 방을 연 사람이 만든 PIN이 필요하다. 주변에 방이 없으면 새로 연다.
class SpotSelectScreen extends ConsumerStatefulWidget {
  const SpotSelectScreen({super.key});

  @override
  ConsumerState<SpotSelectScreen> createState() => _SpotSelectScreenState();
}

class _SpotSelectScreenState extends ConsumerState<SpotSelectScreen> {
  @override
  void initState() {
    super.initState();
    // 이미 권한이 있으면 바로 위치를 읽는다(권한 요청은 버튼을 눌렀을 때).
    Future.microtask(() => ref.read(locationProvider.notifier).refresh());
  }

  void _enter(Spot room) {
    final db = ref.read(demoStoreProvider);
    // 내가 연 방은 PIN 없이 바로 주제 설정으로
    context.push(
      db.isCreator(room.id)
          ? Routes.topicSetup(spotId: room.id)
          : Routes.spotVerify(room.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final loc = ref.watch(locationProvider);
    final now = DateTime.now();
    final unread = db.unreadTotal(now);
    final radius = AppLimits.roomRadiusMeters.round();

    final nearby = loc.hasPoint
        ? db.nearby(loc.point!)
        : const <(Spot, double)>[];
    final inRange = [
      for (final e in nearby)
        if (e.$2 <= AppLimits.roomRadiusMeters) e,
    ];
    final outOfRange = [
      for (final e in nearby)
        if (e.$2 > AppLimits.roomRadiusMeters) e,
    ];

    Widget row((Spot, double) e, {required bool enabled}) => _RoomRow(
      room: e.$1,
      distance: e.$2,
      headcount: db.headcount(e.$1.id, now),
      creatorName: db.isCreator(e.$1.id)
          ? null
          : db.user(e.$1.creatorUid ?? '')?.nickname,
      mine: db.isCreator(e.$1.id),
      enabled: enabled,
      onTap: enabled ? () => _enter(e.$1) : null,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '내 대화',
            onPressed: () => context.go(Routes.chats),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
          IconButton(
            tooltip: '마이',
            onPressed: () => context.go(Routes.my),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(locationProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  PageHeader(
                    title: '${db.me?.nickname ?? ''}님 주변\n${radius}m 안의 대화방',
                    description:
                        '같은 공간에 있는 사람끼리만 대화해요.\n방을 연 사람에게 PIN을 받아 입장하세요.',
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.lg,
                    ),
                  ),
                  const LocationBar(),
                  const SizedBox(height: AppSpacing.sm),
                  switch (loc.status) {
                    LocationStatus.unknown ||
                    LocationStatus.loading when !loc.hasPoint => const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(height: AppSpacing.md),
                            Text('주변 방을 찾고 있어요', style: AppTypography.body),
                          ],
                        ),
                      ),
                    ),
                    LocationStatus.denied ||
                    LocationStatus.deniedForever ||
                    LocationStatus.serviceOff => _LocationNeeded(
                      status: loc.status,
                    ),
                    _ => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (inRange.isEmpty)
                          EmptyState(
                            icon: Icons.wifi_tethering_rounded,
                            title: '주변 ${radius}m에 열린 방이 없어요',
                            message: '지금 있는 곳에 첫 방을 열어 보세요.\n같은 공간 사람들이 PIN으로 들어올 수 있어요.',
                          )
                        else ...[
                          SectionLabel('입장할 수 있는 방 ${inRange.length}'),
                          for (final e in inRange) row(e, enabled: true),
                        ],
                        if (outOfRange.isNotEmpty) ...[
                          SectionLabel('${radius}m 밖이라 입장할 수 없어요'),
                          for (final e in outOfRange) row(e, enabled: false),
                        ],
                      ],
                    ),
                  },
                ],
              ),
            ),
          ),
          if (loc.hasPoint)
            BottomCta(
              child: FilledButton.icon(
                onPressed: () => context.push(Routes.roomCreate),
                icon: const Icon(Icons.add_rounded),
                label: const Text('이 근처에 새 방 열기'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.distance,
    required this.headcount,
    required this.creatorName,
    required this.mine,
    required this.enabled,
    required this.onTap,
  });

  final Spot room;
  final double distance;
  final int headcount;
  final String? creatorName;
  final bool mine;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      formatDistance(distance),
      if (mine) '내가 연 방' else if (creatorName != null) '$creatorName님이 연 방',
    ].join(' · ');
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: ListRow(
          onTap: onTap,
          showChevron: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md - 2,
          ),
          leading: IconTile(
            room.isEvent ? Icons.celebration_outlined : Icons.forum_outlined,
            size: 48,
            color: enabled ? AppColors.primarySoft : AppColors.fill,
            iconColor: enabled ? AppColors.primary : AppColors.secondary,
          ),
          title: room.name,
          titleStyle: AppTypography.subtitle,
          subtitle: sub,
          trailing: !enabled
              ? const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.tertiary,
                  size: 20,
                )
              : headcount == 0
              ? const StatusPill('비어 있음', tone: PillTone.muted)
              : StatusPill('$headcount명', tone: PillTone.active),
        ),
      ),
    );
  }
}

/// 위치 권한·서비스가 없을 때 안내
class _LocationNeeded extends ConsumerWidget {
  const _LocationNeeded({required this.status});

  final LocationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(locationProvider.notifier);
    final (title, message, label, action) = switch (status) {
      LocationStatus.deniedForever => (
        '설정에서 위치 권한을 켜 주세요',
        '위치 권한이 꺼져 있어 주변 방을 찾을 수 없어요.',
        '설정 열기',
        controller.openSettings,
      ),
      LocationStatus.serviceOff => (
        '기기 위치가 꺼져 있어요',
        '기기의 위치 서비스를 켠 뒤 다시 시도해 주세요.',
        '다시 시도',
        () => controller.refresh(request: true),
      ),
      _ => (
        '주변 방을 찾으려면\n위치 권한이 필요해요',
        '${AppLimits.roomRadiusMeters.round()}m 안에 열린 방을 찾을 때만 쓰고, 위치는 저장하지 않아요.',
        '위치 권한 허용',
        () => controller.refresh(request: true),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.section),
        ),
        child: Column(
          children: [
            const IconTile(
              Icons.location_on_rounded,
              size: 56,
              color: AppColors.primarySoft,
              iconColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.title.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: action, child: Text(label)),
          ],
        ),
      ),
    );
  }
}
