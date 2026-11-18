import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/push/push_controller.dart';
import '../../../core/push/push_message.dart';
import '../../../core/push/push_platform.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/demo/demo_providers.dart';
import '../../../data/live/live_mode.dart';
import '../../../data/live/push_repository.dart';

/// 마이페이지 > 알림: 알림 권한, 토픽(공지·이벤트) 구독, 받은 알림 목록.
/// 모든 값은 PushController(Notifier) 상태라 알림이 오면 바로 반영된다.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(
        backgroundColor: AppColors.groupedBackground,
        title: const Text('알림'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: const [
          _PermissionCard(),
          SizedBox(height: AppSpacing.sm + 2),
          _TopicCard(),
          _DebugCard(),
          _Inbox(),
        ],
      ),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushProvider.select((s) => s.permission));
    final (icon, title, message) = switch (permission) {
      PushPermission.granted || PushPermission.provisional => (
        Icons.notifications_active_rounded,
        '알림을 받고 있어요',
        '대화 요청·수락·새 메시지를 앱이 닫혀 있어도 알려드려요.',
      ),
      PushPermission.denied => (
        Icons.notifications_off_outlined,
        '알림이 꺼져 있어요',
        '휴대폰 설정 > 앱 > BIND > 알림에서 켜 주세요.',
      ),
      PushPermission.unknown => (
        Icons.notifications_none_rounded,
        '알림을 켜 주세요',
        '대화 요청이 오면 바로 알 수 있어요.',
      ),
    };
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.subtitle),
                    Text(message, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          if (permission == PushPermission.unknown) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () =>
                  ref.read(pushProvider.notifier).requestPermission(),
              child: const Text('알림 허용하기'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 공개 토픽(공지·이벤트) 구독
class _TopicCard extends ConsumerWidget {
  const _TopicCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(pushProvider.select((s) => s.topics));
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (final MapEntry(key: topic, value: label)
              in PushTopics.labels.entries)
            Row(
              children: [
                Expanded(child: Text(label, style: AppTypography.subtitle)),
                Switch(
                  value: topics.contains(topic),
                  onChanged: (on) =>
                      ref.read(pushProvider.notifier).setTopic(topic, on: on),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 개발 빌드에서만: 내 기기로 테스트 알림 보내기(토큰 발송 / 토픽 발송)
class _DebugCard extends ConsumerWidget {
  const _DebugCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode || !ref.watch(liveModeProvider)) {
      return const SizedBox.shrink();
    }
    Future<void> send(bool viaTopic, {int delaySeconds = 0}) async {
      final messenger = ScaffoldMessenger.of(context);
      final call = ref
          .read(pushRepositoryProvider)
          .sendTest(viaTopic: viaTopic, delaySeconds: delaySeconds);
      if (delaySeconds > 0) {
        // 그사이 앱을 닫으면 응답을 못 받으므로 기다리지 않는다(알림은 서버가 보낸다).
        unawaited(call.catchError((Object _) {}));
        messenger.showSnackBar(
          SnackBar(content: Text('$delaySeconds초 뒤에 보내요. 앱을 닫아 보세요')),
        );
        return;
      }
      try {
        await call;
        messenger.showSnackBar(const SnackBar(content: Text('테스트 알림을 보냈어요')));
      } on FirebaseFunctionsException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('보내지 못했어요 (${e.code})')));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
      child: SectionCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('개발용 테스트', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => send(false),
                    child: const Text('토큰으로 보내기'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => send(true),
                    child: const Text('토픽으로 보내기'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => send(false, delaySeconds: 10),
              child: const Text('10초 뒤 보내기(백그라운드·종료 상태 시험)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 받은 알림 목록(누르면 그 화면으로)
class _Inbox extends ConsumerWidget {
  const _Inbox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(pushProvider.select((s) => s.inbox));
    final hasUnread = inbox.any((m) => !m.read);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          '받은 알림',
          trailing: hasUnread
              ? TextButton(
                  onPressed: () =>
                      ref.read(pushProvider.notifier).markAllRead(),
                  child: const Text('모두 읽음'),
                )
              : null,
        ),
        if (inbox.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              '아직 받은 알림이 없어요',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          )
        else
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final m in inbox)
                  _InboxRow(key: ValueKey(m.id), message: m),
              ],
            ),
          ),
      ],
    );
  }
}

class _InboxRow extends ConsumerWidget {
  const _InboxRow({required this.message, super.key});

  final PushMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = message;
    final now = ref.watch(clockProvider);
    return Pressable(
      borderRadius: 0,
      onTap: () => ref.read(pushProvider.notifier).open(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
              child: CircleAvatar(
                radius: 3,
                backgroundColor: m.read
                    ? Colors.transparent
                    : AppColors.primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: AppTypography.subtitle.copyWith(
                      color: m.read ? AppColors.secondary : AppColors.heading,
                    ),
                  ),
                  if (m.body.isNotEmpty)
                    Text(
                      m.body,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              TimeFormat.relative(m.receivedAt, now),
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
