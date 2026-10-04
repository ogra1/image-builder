import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

/// Standard heading for a wizard step.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Informational, warning or error banner.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon,
    this.kind = BannerKind.warning,
    this.trailing,
  });

  final String message;
  final IconData? icon;
  final BannerKind kind;

  /// Optional action shown at the right edge, e.g. a "Retry" button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, Color fg, IconData fallback) = switch (kind) {
      BannerKind.info => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        YaruIcons.question_filled,
      ),
      BannerKind.warning => (
        Colors.amber.shade300.withValues(alpha: 0.45),
        Colors.black87,
        YaruIcons.warning_filled,
      ),
      BannerKind.error => (
        scheme.errorContainer.withValues(alpha: 0.5),
        scheme.onErrorContainer,
        YaruIcons.error_filled,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: kind == BannerKind.info ? 0.5 : 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon ?? fallback, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: fg)),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

enum BannerKind { info, warning, error }

/// Section heading used inside step bodies.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Consistent outer padding for step bodies.
class StepBody extends StatelessWidget {
  const StepBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Content is top-aligned and spans the pane width. (A maxWidth
    // ConstrainedBox here would be a no-op: the scroll view hands the
    // child a tight width, which clamps any max away.)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}
