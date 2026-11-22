import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../constants/app_limits.dart';

/// 누르면 살짝 줄어들고 회색 면이 깔리는 탭 영역(카드·리스트 행).
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.borderRadius = AppRadius.section,
    this.color = Colors.transparent,
    this.scale = 0.98,
    this.haptic = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color color;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _down
                ? Color.alphaBlend(
                    AppColors.stateLayer.withValues(alpha: 0.05),
                    widget.color == Colors.transparent
                        ? AppColors.canvas
                        : widget.color,
                  )
                : widget.color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 회색 배경 위의 흰 섹션 카드
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Pressable(
        onTap: onTap,
        color: AppColors.canvas,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 아이콘 + 제목 + 설명 + 오른쪽 요소로 이뤄진 리스트 행
class ListRow extends StatelessWidget {
  const ListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.titleStyle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        titleStyle ??
                        AppTypography.bodyLarge.copyWith(
                          color: AppColors.heading,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (showChevron && onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.tertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 둥근 사각 아이콘 배지(리스트 행 앞)
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    this.size = 40,
    this.color = AppColors.fill,
    this.iconColor = AppColors.heading,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.52, color: iconColor),
    );
  }
}

/// 닉네임 첫 글자 원형 아바타. 프로필 사진은 쓰지 않는다(US-W05).
/// 닉네임마다 정해진 옅은 색을 써서 목록에서 구분되게 한다.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(
    this.name, {
    this.size = 40,
    this.dimmed = false,
    super.key,
  });

  final String name;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = dimmed || name.isEmpty
        ? (AppColors.fill, AppColors.tertiary)
        : AppColors.avatarTints[name.runes.fold(0, (a, b) => a + b) %
              AppColors.avatarTints.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: AppTypography.subtitle.copyWith(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// 그룹 채팅방 아바타(US-025). 사람 아바타([InitialAvatar])와 모양을 맞춘 원형.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.groups_rounded,
        size: size * 0.5,
        color: AppColors.primary,
      ),
    );
  }
}

/// "좋았어요" [AppLimits.trustBadgeThreshold]회 이상 받은 사람 표시(US-017)
class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.control / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 3),
          Text(
            '좋았어요 ${AppLimits.trustBadgeThreshold}+',
            style: AppTypography.caption.copyWith(
              color: AppColors.body,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 작은 회색 라벨(직무 태그·카테고리 등)
class MetaLabel extends StatelessWidget {
  const MetaLabel(this.text, {this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            text,
            style: AppTypography.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 빈 상태 안내
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon, size: 64, iconColor: AppColors.tertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.title.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 화면 하단 고정 CTA 영역. 위쪽은 내용이 자연스럽게 사라지도록 흰색으로 흐린다.
class BottomCta extends StatelessWidget {
  const BottomCta({
    required this.child,
    this.top,
    this.background = AppColors.canvas,
    super.key,
  });

  final Widget child;
  final Widget? top;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.withValues(alpha: 0), background],
          stops: const [0, 0.25],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page - 4,
            AppSpacing.lg,
            AppSpacing.page - 4,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) ...[top!, const SizedBox(height: AppSpacing.md)],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 숫자 배지(안 읽은 메시지·대기 중 요청)
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.caption.copyWith(
          color: AppColors.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// 섹션 제목
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page - 8,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 상태 표시 알약(대기 중·수락됨 등)
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {this.tone = PillTone.neutral, super.key});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (AppColors.fill, AppColors.body),
      PillTone.active => (AppColors.primarySoft, AppColors.primary),
      PillTone.strong => (AppColors.heading, AppColors.canvas),
      PillTone.muted => (AppColors.fill, AppColors.tertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.control / 1.5),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum PillTone { neutral, active, strong, muted }

/// 화면 상단의 큰 제목 + 설명
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.description,
    this.eyebrow,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.sm,
      AppSpacing.page,
      AppSpacing.xl - 8,
    ),
    super.key,
  });

  final String title;
  final String? description;
  final Widget? eyebrow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            eyebrow!,
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(title, style: AppTypography.display),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 단일 선택 칩(직무·카테고리·필터). 선택되면 파란 면.
class SelectChip extends StatelessWidget {
  const SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 가로로 꽉 채움(균등 분할할 때)
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.96,
        borderRadius: AppRadius.full,
        color: selected ? AppColors.primary : AppColors.fill,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: compact ? 36 : 42,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
          // 너비는 글자에 맞추고(expand가 아니면), 세로만 가운데 정렬
          child: Align(
            widthFactor: expand ? null : 1,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontSize: compact ? 14 : 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.onPrimary : AppColors.body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
