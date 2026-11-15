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
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_store.dart';

/// 체크인 > 주제 설정 (US-005, US-014, US-016)
///
/// - [spotId]: 코드 인증 직후 새 체크인
/// - [editId]: 내 체크인의 주제 수정
/// - [add]: BIND+ 사용자의 주제 추가
class TopicSetupScreen extends ConsumerStatefulWidget {
  const TopicSetupScreen({
    this.spotId,
    this.editId,
    this.add = false,
    super.key,
  });

  final String? spotId;
  final String? editId;
  final bool add;

  @override
  ConsumerState<TopicSetupScreen> createState() => _TopicSetupScreenState();
}

class _TopicSetupScreenState extends ConsumerState<TopicSetupScreen> {
  final _topic = TextEditingController();
  TopicCategory? _category;
  StayDuration _stay = StayDuration.twoHours;

  bool get _isNewCheckin => widget.editId == null && !widget.add;

  @override
  void initState() {
    super.initState();
    final editing = widget.editId == null
        ? null
        : ref.read(demoStoreProvider).checkin(widget.editId!);
    if (editing != null) {
      _topic.text = editing.topic;
      _category = editing.category;
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  bool get _valid => _topic.text.trim().isNotEmpty && _category != null;

  Future<void> _openExamples() async {
    final picked = await context.push<String>(
      Routes.topicExamples(_category!.name),
    );
    if (picked == null) return;
    setState(() {
      _topic.text = picked;
      _topic.selection = TextSelection.collapsed(offset: picked.length);
    });
  }

  void _submit() {
    final store = ref.read(demoStoreProvider.notifier);
    final topic = _topic.text.trim();
    if (widget.editId != null) {
      store.updateTopic(widget.editId!, topic, _category!);
      context.pop();
      _snack('주제를 바꿨어요');
    } else if (widget.add) {
      store.addTopic(topic, _category!);
      context.pop();
      _snack('주제를 추가했어요');
    } else {
      // TODO(firebase): checkins 문서 생성
      store.checkIn(
        spotId: widget.spotId!,
        topic: topic,
        category: _category!,
        stay: _stay,
      );
      context.go(Routes.spot);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(demoStoreProvider);
    final spot = db.spot(
      widget.spotId ?? db.myCheckins(DateTime.now()).firstOrNull?.spotId,
    );
    final title = widget.editId != null
        ? '주제 수정'
        : widget.add
        ? '주제 추가'
        : '주제 설정';
    final endsAt = DateTime.now().add(_stay.duration);

    return Scaffold(
      appBar: AppBar(title: _isNewCheckin ? null : Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              children: [
                PageHeader(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xl - 8,
                  ),
                  eyebrow: spot == null
                      ? null
                      : MetaLabel(spot.name, icon: Icons.place_outlined),
                  title: _isNewCheckin
                      ? '지금 어떤 얘기를\n하고 싶으세요?'
                      : '$title할 내용을\n적어 주세요',
                  description: _isNewCheckin ? '같은 공간 사람들에게 이 한 줄이 보여요.' : null,
                ),
                const _Label('카테고리'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in TopicCategory.values)
                      SelectChip(
                        label: c.label,
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    const Expanded(child: _Label('주제 한 줄')),
                    TextButton.icon(
                      onPressed: _category == null ? null : _openExamples,
                      icon: const Icon(Icons.lightbulb_outline, size: 16),
                      label: const Text('예시 보기'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _topic,
                  maxLength: AppLimits.topicMaxLength,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: _category == null
                        ? '카테고리를 고르면 예시도 볼 수 있어요'
                        : '예) ${topicExamples[_category!]!.first}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                if (widget.editId == null && db.recentTopics.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '최근 쓴 주제',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (topic, category) in db.recentTopics)
                    _RecentTopicTile(
                      topic: topic,
                      category: category,
                      onTap: () => setState(() {
                        _topic.text = topic;
                        _category = category;
                      }),
                      onDelete: () => ref
                          .read(demoStoreProvider.notifier)
                          .deleteRecentTopic(topic),
                    ),
                ],

                if (_isNewCheckin) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const _Label('얼마나 머무르세요?'),
                  Row(
                    children: [
                      for (final s in StayDuration.values) ...[
                        Expanded(
                          child: SelectChip(
                            label: s.label,
                            expand: true,
                            selected: _stay == s,
                            onTap: () => setState(() => _stay = s),
                          ),
                        ),
                        if (s != StayDuration.values.last)
                          const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${TimeFormat.clock(endsAt)}까지 내 카드가 보여요. 시간이 끝나면 자동으로 내려가요.',
                    style: AppTypography.caption,
                  ),
                ],
              ],
            ),
          ),
          BottomCta(
            child: FilledButton(
              onPressed: _valid ? _submit : null,
              child: Text(
                widget.editId != null
                    ? '저장'
                    : widget.add
                    ? '주제 추가'
                    : '체크인하기',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTopicTile extends StatelessWidget {
  const _RecentTopicTile({
    required this.topic,
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  final String topic;
  final TopicCategory category;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Pressable(
        onTap: onTap,
        color: AppColors.fill,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  topic,
                  style: AppTypography.body.copyWith(color: AppColors.heading),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(category.label, style: AppTypography.caption),
              IconButton(
                tooltip: '최근 주제에서 지우기',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
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
