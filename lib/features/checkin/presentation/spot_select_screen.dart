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
import '../../../data/demo/demo_store.dart';
import '../../../data/models/spot.dart';

/// 체크인 (US-004, US-005). 체크인 전 홈.
///
/// 한 화면에서 장소를 자유롭게 입력하고 주제 한 줄을 올리면 끝.
/// 같은 장소를 입력한 사람끼리 서로의 카드를 보고 대화를 신청한다.
/// 입력하는 동안 다른 사람이 이미 입력한 장소를 추천해 같은 이름으로 모이게 한다.
class SpotSelectScreen extends ConsumerStatefulWidget {
  const SpotSelectScreen({super.key});

  @override
  ConsumerState<SpotSelectScreen> createState() => _SpotSelectScreenState();
}

class _SpotSelectScreenState extends ConsumerState<SpotSelectScreen> {
  final _place = TextEditingController();
  final _placeFocus = FocusNode();
  final _topic = TextEditingController();
  TopicCategory? _category;

  @override
  void initState() {
    super.initState();
    _placeFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _place.dispose();
    _placeFocus.dispose();
    _topic.dispose();
    super.dispose();
  }

  void _pickPlace(String name) {
    setState(() {
      _place.text = name;
      _place.selection = TextSelection.collapsed(offset: name.length);
    });
    _placeFocus.unfocus();
  }

  Future<void> _openExamples() async {
    final picked = await context.push<String>(
      Routes.topicExamples(_category!.name),
    );
    if (picked == null) return;
    setState(() => _topic.text = picked);
  }

  bool get _valid =>
      _place.text.trim().length >= AppLimits.placeNameMin &&
      _category != null &&
      _topic.text.trim().isNotEmpty;

  void _submit() {
    HapticFeedback.mediumImpact();
    ref
        .read(demoStoreProvider.notifier)
        .checkIn(
          placeName: _place.text,
          topic: _topic.text,
          category: _category!,
        );
    context.go(Routes.spot);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final now = DateTime.now();
    final unread = db.unreadTotal(now);
    final query = _place.text.trim();
    final match = query.length >= AppLimits.placeNameMin
        ? db.spotByName(query)
        : null;
    final suggestions = query.isEmpty
        ? const <Spot>[]
        : db.suggestSpots(query, now).where((s) => s != match).take(4).toList();
    final quickPicks = [
      ...db.recentSpots,
      for (final s in db.activeSpots(now))
        if (!db.recentSpots.contains(s)) s,
    ].take(6).toList();
    final people = match == null ? 0 : db.headcount(match.id, now);

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
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              children: [
                PageHeader(
                  title: '${db.me?.nickname ?? ''}님,\n지금 어디에 계세요?',
                  description: '같은 장소를 적은 사람끼리 서로의 주제를 보고 대화해요.',
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.xl - 8,
                  ),
                ),

                // ── 장소 ──
                const _Label('장소'),
                TextField(
                  controller: _place,
                  focusNode: _placeFocus,
                  maxLength: AppLimits.placeNameMax,
                  textInputAction: TextInputAction.next,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '예) 성수 워크라운지, 판교 컨퍼런스',
                    prefixIcon: const Icon(
                      Icons.place_outlined,
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
                            onPressed: () => setState(_place.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (match != null)
                  _PlaceHint(
                    icon: Icons.groups_rounded,
                    text: people > 0
                        ? '${match.name}에 지금 $people명이 있어요. 같은 곳으로 들어가요.'
                        : '${match.name}로 들어가요.',
                    active: true,
                  )
                else if (query.length >= AppLimits.placeNameMin)
                  _PlaceHint(
                    icon: Icons.add_location_alt_outlined,
                    text: '‘$query’ 장소를 새로 열어요.',
                    active: false,
                  ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '혹시 이 장소인가요?',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final s in suggestions)
                    _SuggestionRow(
                      spot: s,
                      people: db.headcount(s.id, now),
                      onTap: () => _pickPlace(s.name),
                    ),
                ],
                if (query.isEmpty && quickPicks.isNotEmpty) ...[
                  Wrap(
                    spacing: AppSpacing.xs + 2,
                    runSpacing: AppSpacing.xs + 2,
                    children: [
                      for (final s in quickPicks)
                        SelectChip(
                          label: db.headcount(s.id, now) > 0
                              ? '${s.name} ${db.headcount(s.id, now)}'
                              : s.name,
                          compact: true,
                          selected: false,
                          onTap: () => _pickPlace(s.name),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                // ── 주제 ──
                const _Label('어떤 얘기를 하고 싶으세요?'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in TopicCategory.values)
                      SelectChip(
                        label: c.label,
                        compact: true,
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _topic,
                  maxLength: AppLimits.topicMaxLength,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: _category == null
                        ? '주제 한 줄'
                        : '예) ${topicExamples[_category!]!.first}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _category == null ? null : _openExamples,
                    icon: const Icon(Icons.lightbulb_outline, size: 16),
                    label: const Text('예시 주제 보기'),
                  ),
                ),
              ],
            ),
          ),
          BottomCta(
            child: FilledButton(
              onPressed: _valid ? _submit : null,
              child: const Text('체크인하기'),
            ),
          ),
        ],
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

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.spot,
    required this.people,
    required this.onTap,
  });

  final Spot spot;
  final int people;
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
              size: 18,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                spot.name,
                style: AppTypography.body.copyWith(color: AppColors.heading),
              ),
            ),
            if (people > 0)
              StatusPill('$people명', tone: PillTone.active)
            else
              const StatusPill('비어 있음', tone: PillTone.muted),
          ],
        ),
      ),
    );
  }
}
