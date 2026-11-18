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
import 'keyword_picker.dart';

/// 체크인 > 주제 수정·추가 (US-005, US-014, US-016)
///
/// 새 체크인은 체크인 화면에서 한 번에 한다. 이 화면은 체크인 뒤에 쓴다.
/// - [editId]: 내 체크인의 주제 수정
/// - [add]: BIND+ 사용자의 주제 추가
class TopicSetupScreen extends ConsumerStatefulWidget {
  const TopicSetupScreen({this.editId, this.add = false, super.key});

  final String? editId;
  final bool add;

  @override
  ConsumerState<TopicSetupScreen> createState() => _TopicSetupScreenState();
}

class _TopicSetupScreenState extends ConsumerState<TopicSetupScreen> {
  final _topic = TextEditingController();
  final _keywordCustom = TextEditingController();
  final _keywordCustomFocus = FocusNode();
  TopicCategory? _category;

  @override
  void initState() {
    super.initState();
    final editing = widget.editId == null
        ? null
        : ref.read(demoStoreProvider).checkin(widget.editId!);
    if (editing != null) {
      _topic.text = editing.topic;
      _category = editing.category;
      _keywordCustom.text = editing.categoryCustom ?? '';
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    _keywordCustom.dispose();
    _keywordCustomFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      _topic.text.trim().isNotEmpty &&
      _category != null &&
      (_category != TopicCategory.other ||
          _keywordCustom.text.trim().isNotEmpty);

  Future<void> _openExamples() async {
    final picked = await context.push<String>(
      Routes.topicExamples((_category ?? TopicCategory.smallTalk).name),
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
      store.updateTopic(
        widget.editId!,
        topic,
        _category!,
        categoryCustom: _keywordCustom.text,
      );
      context.pop();
      _snack('주제를 바꿨어요');
    } else {
      store.addTopic(topic, _category!, categoryCustom: _keywordCustom.text);
      context.pop();
      _snack('주제를 추가했어요');
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final spotId = ref.watch(mySpotIdProvider);
    final spotName = spotId == null
        ? null
        : ref.watch(spotProvider(spotId).select((s) => s?.name));
    final recentTopics = widget.editId == null
        ? ref.watch(recentTopicsProvider)
        : const <(String, TopicCategory)>[];
    final title = widget.editId != null ? '주제 수정' : '주제 추가';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                  eyebrow: spotName == null
                      ? null
                      : MetaLabel(spotName, icon: Icons.place_outlined),
                  title: '$title할 내용을\n적어 주세요',
                ),
                // ── 주제 ──
                Row(
                  children: [
                    const Expanded(child: _Label('주제')),
                    TextButton.icon(
                      onPressed: _openExamples,
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
                    hintText:
                        '예) ${topicExamples[_category ?? TopicCategory.smallTalk]!.first}',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 키워드 ──
                const _Label('키워드'),
                KeywordPicker(
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c),
                  customController: _keywordCustom,
                  customFocus: _keywordCustomFocus,
                ),

                if (recentTopics.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '최근 쓴 주제',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (topic, category) in recentTopics)
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
              ],
            ),
          ),
          BottomCta(
            // 글자를 칠 때는 이 버튼만 다시 그린다.
            child: ListenableBuilder(
              listenable: Listenable.merge([_topic, _keywordCustom]),
              builder: (_, _) => FilledButton(
                onPressed: _valid ? _submit : null,
                child: Text(widget.editId != null ? '저장' : '주제 추가'),
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
