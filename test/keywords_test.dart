import 'package:bind_app/core/constants/app_limits.dart';
import 'package:bind_app/core/constants/enums.dart';
import 'package:bind_app/core/constants/topic_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// 키워드 구성(2026-11-23): 커리어 · 일상 · 스터디 3묶음, 묶음마다 10~12개.
void main() {
  test('키워드 묶음은 커리어, 일상, 스터디 순서다', () {
    expect(
      [for (final g in KeywordGroup.values) g.label],
      ['커리어', '일상', '스터디'],
    );
  });

  test('묶음마다 키워드가 10~12개다', () {
    for (final g in KeywordGroup.values) {
      final count = TopicCategory.values.where((c) => c.group == g).length;
      expect(count, inInclusiveRange(10, 12), reason: g.label);
    }
  });

  test('모든 키워드에 예시 주제가 있다(US-014)', () {
    for (final c in TopicCategory.values) {
      final examples = topicExamples[c];
      expect(examples, isNotNull, reason: c.name);
      expect(
        examples!.length,
        inInclusiveRange(3, AppLimits.topicExamplesPerCategory),
        reason: c.name,
      );
    }
  });

  test('라벨이 겹치지 않고, 기타는 직접 입력용으로 남아 있다', () {
    final labels = [for (final c in TopicCategory.values) c.label];
    expect(labels.toSet().length, labels.length);
    expect(TopicCategory.other.label, '기타');
  });
}
