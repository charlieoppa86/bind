import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_limits.dart';
import '../../../core/constants/enums.dart';
import '../../../core/constants/topic_content.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/models/place.dart';
import '../../../data/models/spot.dart';
import '../../../data/place/place_search.dart';
import 'keyword_picker.dart';
import '../../../core/widgets/bind_logo.dart';

/// 체크인 (US-004, US-005). 체크인 전 홈.
///
/// 한 화면에서 장소를 검색해 고르고 주제 한 줄을 올리면 끝.
/// 장소는 카카오 장소 검색으로 고르고, 같은 카카오 장소를 고른 사람끼리
/// 서로의 카드를 보고 대화를 요청한다.
class SpotSelectScreen extends ConsumerStatefulWidget {
  const SpotSelectScreen({super.key});

  @override
  ConsumerState<SpotSelectScreen> createState() => _SpotSelectScreenState();
}

/// 화면 상태는 컨트롤러·ValueNotifier에 두고 setState를 쓰지 않는다.
/// 글자를 치면 그 입력에 기대는 부분(검색 결과, 버튼)만 다시 그린다.
class _SpotSelectScreenState extends ConsumerState<SpotSelectScreen> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  final _topic = TextEditingController();
  final _place = ValueNotifier<Place?>(null);
  final _category = ValueNotifier<TopicCategory?>(null);
  final _keywordCustom = TextEditingController();
  final _keywordCustomFocus = FocusNode();

  /// US-025 이 카드로 그룹 채팅도 열지
  final _openGroupChat = ValueNotifier<bool>(false);

  /// 연령대·성별(필수). 지난 체크인 때 고른 값을 미리 채운다.
  late final _ageBand = ValueNotifier<AgeBand?>(ref.read(meProvider)?.ageBand);
  late final _gender = ValueNotifier<Gender?>(ref.read(meProvider)?.gender);

  @override
  void dispose() {
    _ageBand.dispose();
    _gender.dispose();
    _openGroupChat.dispose();
    _keywordCustom.dispose();
    _keywordCustomFocus.dispose();
    _query.dispose();
    _queryFocus.dispose();
    _topic.dispose();
    _place.dispose();
    _category.dispose();
    super.dispose();
  }

  void _pick(Place place) {
    HapticFeedback.selectionClick();
    _place.value = place;
    _queryFocus.unfocus();
  }

  void _changePlace() {
    _place.value = null;
    _query.clear();
    _queryFocus.requestFocus();
  }

  bool get _valid =>
      _place.value != null &&
      _topic.text.trim().isNotEmpty &&
      _category.value != null &&
      (_category.value != TopicCategory.other ||
          _keywordCustom.text.trim().isNotEmpty) &&
      _ageBand.value != null &&
      _gender.value != null;

  void _submit() {
    HapticFeedback.mediumImpact();
    ref
        .read(demoStoreProvider.notifier)
        .checkIn(
          place: _place.value!,
          topic: _topic.text,
          category: _category.value!,
          categoryCustom: _keywordCustom.text,
          openGroupChat: _openGroupChat.value,
          ageBand: _ageBand.value!,
          gender: _gender.value!,
        );
    context.go(Routes.spot);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        title: const BindMark(),
        actions: [
          const _ChatsButton(),
          IconButton(
            tooltip: '마이페이지',
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
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              children: [
                const _Greeting(),

                // ── 장소 ──
                const _Label('장소'),
                ValueListenableBuilder<Place?>(
                  valueListenable: _place,
                  builder: (_, place, _) => place != null
                      ? _SelectedPlace(place: place, onChange: _changePlace)
                      : _PlaceSearchField(
                          controller: _query,
                          focusNode: _queryFocus,
                          onPick: _pick,
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── 대화 방식(장소와 주제 사이) ──
                const _Label('대화 방식'),
                ValueListenableBuilder<bool>(
                  valueListenable: _openGroupChat,
                  builder: (_, on, _) => _GroupChatOption(
                    value: on,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      _openGroupChat.value = v;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── 주제 ──
                const _Label('주제'),
                ValueListenableBuilder<TopicCategory?>(
                  valueListenable: _category,
                  builder: (_, category, _) => TextField(
                    controller: _topic,
                    maxLength: AppLimits.topicMaxLength,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          '예) ${topicExamples[category ?? TopicCategory.smallTalk]!.first}',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── 키워드 ──
                const _Label('키워드'),
                ValueListenableBuilder<TopicCategory?>(
                  valueListenable: _category,
                  builder: (_, selected, _) => KeywordPicker(
                    selected: selected,
                    onSelected: (c) => _category.value = c,
                    customController: _keywordCustom,
                    customFocus: _keywordCustomFocus,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 연령대·성별(필수, 카드에 보임) ──
                const _Label('연령대 · 성별'),
                _ChoiceRow<AgeBand>(
                  values: AgeBand.values,
                  selected: _ageBand,
                  label: (a) => a.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ChoiceRow<Gender>(
                  values: Gender.values,
                  selected: _gender,
                  label: (g) => g.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '같은 장소 사람들이 보는 내 카드에 함께 보여요. 다음 체크인 때 그대로 채워 둘게요.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          BottomCta(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _place,
                _topic,
                _category,
                _keywordCustom,
                _ageBand,
                _gender,
              ]),
              builder: (_, _) => FilledButton(
                onPressed: _valid ? _submit : null,
                child: const Text('체크인하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 "내 대화" 버튼 — 안 읽은 수만 구독
class _ChatsButton extends ConsumerWidget {
  const _ChatsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadTotalProvider);
    return IconButton(
      tooltip: '내 대화',
      onPressed: () => context.go(Routes.chats),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.chat_bubble_outline_rounded),
      ),
    );
  }
}

/// "OO님, 지금 어디에 계세요?" — 닉네임만 구독
class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(meProvider.select((m) => m?.nickname ?? ''));
    return PageHeader(
      title: '$nickname님,\n지금 어디에 계세요?',
      description: '같은 장소를 고른 사람끼리 서로의 주제를 보고 대화해요.',
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xl - 8,
      ),
    );
  }
}

/// 장소 검색창 + (입력 전) 빠른 선택 칩 / (입력 후) 검색 결과
class _PlaceSearchField extends StatelessWidget {
  const _PlaceSearchField({
    required this.controller,
    required this.focusNode,
    required this.onPick,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        final query = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: AppLimits.placeSearchMaxLength,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.heading,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '장소 이름으로 검색 (예: 성수 카페)',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.secondary,
                ),
                counterText: '',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '지우기',
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.tertiary,
                          size: 20,
                        ),
                        onPressed: controller.clear,
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (query.isEmpty)
              _QuickPicks(onPick: onPick)
            else
              _SearchResults(query: query, onPick: onPick),
          ],
        );
      },
    );
  }
}

/// 검색 결과(입력이 멈춘 뒤 한 번만 검색)
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.onPick});

  final String query;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.length < AppLimits.placeSearchMinLength) {
      return const _SearchNote('두 글자 이상 입력하면 장소를 찾아드려요.');
    }
    final results = ref.watch(placeSearchResultsProvider(query));
    return switch (results) {
      AsyncData(:final value) when value.isEmpty => const _SearchNote(
        '검색 결과가 없어요. 동네 이름을 함께 적어 보세요. (예: 성수 카페)',
      ),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in value)
            _PlaceRow(key: ValueKey(p.id), place: p, onTap: () => onPick(p)),
          const _KakaoAttribution(),
        ],
      ),
      AsyncError() => const _SearchNote('장소 검색이 잠시 안 돼요. 잠시 후 다시 시도해 주세요.'),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.secondary,
            ),
          ),
        ),
      ),
    };
  }
}

class _SearchNote extends StatelessWidget {
  const _SearchNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: AppColors.secondary),
      ),
    );
  }
}

/// 검색 결과 출처 표시
class _KakaoAttribution extends StatelessWidget {
  const _KakaoAttribution();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        '장소 정보 제공: 카카오',
        style: AppTypography.caption,
        textAlign: TextAlign.right,
      ),
    );
  }
}

/// 검색 결과 한 줄: 이름 · 업종 · 주소 · 지금 인원(이미 열린 장소면)
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.onTap, super.key});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 20,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _PlaceText(place: place)),
            const SizedBox(width: AppSpacing.sm),
            _PlaceHeadcount(placeId: place.id),
          ],
        ),
      ),
    );
  }
}

class _PlaceText extends StatelessWidget {
  const _PlaceText({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place.name,
          style: AppTypography.body.copyWith(
            color: AppColors.heading,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          [
            if (place.category.isNotEmpty) place.category,
            place.address,
          ].join(' · '),
          style: AppTypography.caption,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// 그 장소에 지금 있는 사람 수(이미 누군가 체크인한 장소일 때만)
class _PlaceHeadcount extends ConsumerWidget {
  const _PlaceHeadcount({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotId = ref.watch(
      spotByPlaceIdProvider(placeId).select((s) => s?.id),
    );
    if (spotId == null) return const SizedBox.shrink();
    final people = ref.watch(headcountProvider(spotId));
    if (people == 0) return const SizedBox.shrink();
    return StatusPill('지금 $people명', tone: PillTone.active);
  }
}

/// 고른 장소 카드 + 같은 장소 안내
class _SelectedPlace extends ConsumerWidget {
  const _SelectedPlace({required this.place, required this.onChange});

  final Place place;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotId = ref.watch(
      spotByPlaceIdProvider(place.id).select((s) => s?.id),
    );
    final people = spotId == null ? 0 : ref.watch(headcountProvider(spotId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _PlaceText(place: place)),
              TextButton(onPressed: onChange, child: const Text('변경')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PlaceHint(
          icon: people > 0
              ? Icons.groups_rounded
              : Icons.add_location_alt_outlined,
          text: people > 0
              ? '지금 $people명이 이 장소에 있어요. 같은 곳으로 들어가요.'
              : '아직 아무도 없어요. 처음으로 체크인해요.',
          active: people > 0,
        ),
      ],
    );
  }
}

/// 입력 전: 최근 간 장소 + 사람이 있는 장소 칩
class _QuickPicks extends ConsumerWidget {
  const _QuickPicks({required this.onPick});

  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSpotsProvider);
    final active = ref.watch(activeSpotsProvider);
    final picks = [
      ...recent,
      for (final s in active)
        if (!recent.contains(s)) s,
    ].take(6).toList();
    if (picks.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs + 2,
      children: [
        for (final s in picks)
          _QuickPickChip(key: ValueKey(s.id), spot: s, onPick: onPick),
      ],
    );
  }
}

class _QuickPickChip extends ConsumerWidget {
  const _QuickPickChip({required this.spot, required this.onPick, super.key});

  final Spot spot;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(headcountProvider(spot.id));
    return SelectChip(
      label: people > 0 ? '${spot.name} $people' : spot.name,
      compact: true,
      selected: false,
      onTap: () => onPick(spot.toPlace()),
    );
  }
}

/// 한 줄 단일 선택(연령대·성별). 고른 칩만 다시 그린다.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.label,
  });

  final List<T> values;
  final ValueNotifier<T?> selected;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T?>(
      valueListenable: selected,
      builder: (_, value, _) => Wrap(
        spacing: AppSpacing.xs + 2,
        runSpacing: AppSpacing.xs + 2,
        children: [
          for (final v in values)
            SelectChip(
              label: label(v),
              compact: true,
              selected: value == v,
              onTap: () => selected.value = v,
            ),
        ],
      ),
    );
  }
}

/// US-025 "그룹 채팅도 열기". 끄면 지금처럼 1:1 요청만 받는다.
class _GroupChatOption extends StatelessWidget {
  const _GroupChatOption({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      color: AppColors.elevated,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              Icons.groups_outlined,
              color: value ? AppColors.primary : AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ChatType.group.label}도 열기',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value
                        ? '같은 장소 사람들이 요청 없이 바로 들어와 함께 이야기해요 '
                              '(최대 ${AppLimits.groupChatMaxMembers}명). '
                              '${ChatType.direct.label} 요청도 그대로 받아요.'
                        : '끄면 ${ChatType.direct.label} 요청만 받아요.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.body.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlaceHint extends StatelessWidget {
  const _PlaceHint({
    required this.icon,
    required this.text,
    required this.active,
  });

  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: active ? AppColors.primary : AppColors.secondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: active ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
