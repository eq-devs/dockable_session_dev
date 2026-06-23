import 'package:flutter/material.dart';

import 'render_session_transform.dart';
import 'session_controller.dart';
import 'session_status.dart';

/// Renders the live session and animates it between [collapsedRect] (the pill
/// slot) and [fullRect] (full screen). The motion is driven at the render layer
/// by [SessionTransform], so the content subtree is built once and only its
/// paint updates per frame (doc §6.2).
///
/// The iron rule (doc §1): while a session exists this widget is **always** in
/// the tree, so the content's `State` is preserved. Minimizing only flips
/// [Offstage] on — the subtree stays mounted, just unpainted and unhittable.
/// [TickerMode] freezes the docked subtree's animations to save power (doc §9).
class SessionHost extends StatelessWidget {
  const SessionHost({
    super.key,
    required this.controller,
    required this.collapsedRect,
    required this.fullRect,
    this.collapsedRadius = 16,
    this.curve = Curves.easeInOutCubic,
  });

  final SessionController controller;

  /// Screen rect of the pill slot (expansion == 0).
  final Rect collapsedRect;

  /// Screen rect of the full-screen session (expansion == 1).
  final Rect fullRect;

  /// Corner radius applied when fully collapsed; lerps to 0 when expanded.
  final double collapsedRadius;

  /// Curve applied to the raw expansion value for the rect interpolation.
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final entry = controller.entry;
    if (entry == null) return const SizedBox.shrink();

    final status = controller.status;
    final offstage = status == SessionStatus.minimized;

    return Positioned.fromRect(
      rect: fullRect,
      child: Offstage(
        offstage: offstage,
        child: TickerMode(
          // Freeze the docked subtree's tickers while minimized.
          enabled: !offstage,
          child: IgnorePointer(
            // Don't accept taps mid-flight; the pill handles taps when docked.
            ignoring: status == SessionStatus.animating,
            child: SessionTransform(
              expansion: controller.expansion,
              closeProgress: controller.closeProgress,
              collapsedRect: collapsedRect,
              fullRect: fullRect,
              collapsedRadius: collapsedRadius,
              curve: curve,
              // Built once: the render layer animates paint, not this subtree.
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: KeyedSubtree(
                  key: entry.contentKey,
                  child: Builder(
                    builder: (ctx) => entry.builder(ctx, controller),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
