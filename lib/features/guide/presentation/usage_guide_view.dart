import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/enums.dart';
import '../../../core/constants/topic_content.dart';

/// 사용법 가이드 3장 스와이프 (US-013).
/// 온보딩(`/onboarding/guide`)과 마이(`/my/guide`)에서 같은 위젯을 재사용한다.
class UsageGuideView extends StatefulWidget {
  const UsageGuideView({required this.onDone, this.showSkip = true, super.key});

  /// 건너뛰기 또는 마지막 장 완료 시 호출
  final VoidCallback onDone;
  final bool showSkip;

  @override
  State<UsageGuideView> createState() => _UsageGuideViewState();
}

class _UsageGuideViewState extends State<UsageGuideView> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: widget.showSkip
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: TextButton(
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                        ),
                        child: const Text('건너뛰기'),
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: const [
                _GuidePage(
                  step: 1,
                  title: '지금 있는 장소를\n적고 체크인해요',
                  body: '장소 이름을 자유롭게 적으면 돼요.\n같은 장소를 적은 사람끼리 서로의 주제를 볼 수 있어요.',
                  visual: _SpotVisual(),
                ),
                _GuidePage(
                  step: 2,
                  title: '얘기하고 싶은 주제\n한 줄을 올려요',
                  body: '사진 대신 주제로 상대를 찾아요.\n신청은 한 마디와 함께 오고, 내가 수락해야 대화가 열려요.',
                  visual: _CardVisual(),
                ),
                _GuidePage(
                  step: 3,
                  title: '이런 주제가\n신청을 많이 받아요',
                  body: '구체적일수록 말 걸기 쉬워져요.',
                  visual: _ExamplesVisual(),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pageCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : AppColors.hairline,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLast
                    ? widget.onDone
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                child: Text(isLast ? '시작하기' : '다음'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  const _GuidePage({
    required this.step,
    required this.title,
    required this.body,
    required this.visual,
  });

  final int step;
  final String title;
  final String body;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $step',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTypography.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: Center(child: visual)),
        ],
      ),
    );
  }
}

BoxDecoration _panel() => BoxDecoration(
  color: AppColors.fill,
  borderRadius: BorderRadius.circular(AppRadius.card),
);

class _SpotVisual extends StatelessWidget {
  const _SpotVisual();

  @override
  Widget build(BuildContext context) {
    Widget place(String name, String meta, bool open) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: open ? AppColors.primarySoft : AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(
              Icons.place_outlined,
              size: 20,
              color: open ? AppColors.primary : AppColors.secondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(name, style: AppTypography.supportingTitle)),
          Text(
            meta,
            style: AppTypography.caption.copyWith(
              color: open ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md - 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 20,
                  color: AppColors.secondary,
                ),
                SizedBox(width: AppSpacing.sm),
                Text('성수 워크라운지', style: AppTypography.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          place('성수 워크라운지', '지금 9명', true),
          place('성수 워크숍 카페', '비어 있음', false),
        ],
      ),
    );
  }
}

class _CardVisual extends StatelessWidget {
  const _CardVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _panel(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '도윤 · ${JobTag.developer.label}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Riverpod 3 마이그레이션 해보신 분?',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: const Text(
                '“저도 지금 하는 중이에요! 얘기해요”',
                style: AppTypography.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamplesVisual extends StatelessWidget {
  const _ExamplesVisual();

  @override
  Widget build(BuildContext context) {
    final examples = [
      topicExamples[TopicCategory.dev]!.first,
      topicExamples[TopicCategory.marketing]!.first,
      topicExamples[TopicCategory.career]![2],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in examples)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(e, style: AppTypography.subtitle)),
              ],
            ),
          ),
      ],
    );
  }
}
