import 'package:flutter/material.dart';

import '../core/session_controller.dart';
import '../core/session_entry.dart';
import '../core/session_status.dart';
import '../rendering/render_session_transform.dart';

/// Renders the live session and animates it between [collapsedRect] (the pill
/// slot) and [fullRect] (full screen). The motion is driven at the render layer
/// by [SessionTransform], so the content subtree is built once per entry and
/// only its paint updates per frame (doc §6.2).
///
/// The iron rule (doc §1): while a session exists this widget is **always** in
/// the tree, so the content's `State` is preserved. Minimizing only flips
/// [Offstage] on — the subtree stays mounted, just unpainted and unhittable.
/// [TickerMode] freezes the docked subtree's animations to save power (doc §9).
class SessionHost extends StatefulWidget {
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
  State<SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<SessionHost> {
  // The content widget is cached per entry: the builder runs once, and later
  // structural rebuilds hand the identical instance back so the framework
  // skips re-diffing the whole subtree. Inherited dependencies (theme, media
  // query, ...) inside the content still trigger rebuilds as usual.
  SessionEntry? _contentEntry;
  Widget? _content;

  Widget _contentFor(SessionEntry entry) {
    if (!identical(entry, _contentEntry)) {
      _contentEntry = entry;
      _content = KeyedSubtree(
        key: entry.contentKey,
        child: Builder(
          builder: (ctx) => entry.builder(ctx, widget.controller),
        ),
      );
    }
    return _content!;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.controller.entry;
    if (entry == null) return const SizedBox.shrink();

    final status = widget.controller.status;
    final offstage = status == SessionStatus.minimized;

    return Positioned.fromRect(
      rect: widget.fullRect,
      child: Offstage(
        offstage: offstage,
        child: TickerMode(
          // Freeze the docked subtree's tickers while minimized.
          enabled: !offstage,
          child: IgnorePointer(
            // Don't accept taps mid-flight; the pill handles taps when docked.
            ignoring: status == SessionStatus.animating,
            // Outer boundary: the per-frame markNeedsPaint inside
            // SessionTransform stops here instead of repainting the app shell.
            child: RepaintBoundary(
              child: SessionTransform(
                expansion: widget.controller.expansion,
                closeProgress: widget.controller.closeProgress,
                collapsedRect: widget.collapsedRect,
                fullRect: widget.fullRect,
                collapsedRadius: widget.collapsedRadius,
                curve: widget.curve,
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  // Inner boundary: the content rasterizes once, so each
                  // animation frame only recomposites the cached layer through
                  // the transform/clip/fade instead of repainting the subtree.
                  child: RepaintBoundary(
                    child: _contentFor(entry),
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
