import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

/// Shows a short-lived, Yaru-styled toast bubble ("message bubble")
/// centered at the top of the window — the GNOME-style way of giving
/// quick feedback (e.g. "copied to clipboard").
///
/// The bubble animates in, stays for [duration], fades out and removes
/// itself from the enclosing [Overlay]. It is purely visual and never
/// intercepts pointer events.
Future<void> showToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = const Duration(milliseconds: 2400),
}) {
  final overlay = context.findAncestorStateOfType<OverlayState>();
  if (overlay == null) {
    // No overlay available (e.g. called outside a MaterialApp) — ignore.
    return Future.value();
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastBubble(
      message: message,
      icon: icon,
      duration: duration,
      onDone: () {
        if (overlay.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return Future.value();
}

class _ToastBubble extends StatefulWidget {
  const _ToastBubble({
    required this.message,
    required this.onDone,
    this.icon,
    this.duration = const Duration(milliseconds: 2400),
  });

  final String message;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble>
    with SingleTickerProviderStateMixin {
  static const _kAnimation = Duration(milliseconds: 220);
  static const _kTopOffset = 52.0; // below the window title bar

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kAnimation,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(kYaruContainerRadius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon ?? YaruIcons.checkmark,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            widget.message,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final t = _animation.value;
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: _kTopOffset),
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, -8 * (1 - t)),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: bubble,
      ),
    );
  }
}
