import 'package:flutter/material.dart';

import 'minimized_session_bar.dart';
import 'session_controller.dart';
import 'session_entry.dart';
import 'session_host.dart';
import 'session_status.dart';

/// Overlays the single persistent session (the animating [SessionHost] and the
/// docked pill) on top of your own app, which you pass as [child].
///
/// Unlike a full scaffold, this widget is unopinionated about navigation: build
/// your own [Scaffold], tabs, and bottom bar inside [child]. The overlay only
/// owns the genuinely hard parts — interpolating the session between full screen
/// and the pill, layering it above [child], and turning the system back gesture
/// into a minimize (doc §1, §6.2, §7). Drive the session with the [controller]
/// you pass; the same controller reaches the session's content via the builder.
///
/// At most one session exists at a time, driven entirely by the controller
/// (open / minimize / restore / close) — there are no drag gestures (doc §11).
class SessionOverlay extends StatelessWidget {
  const SessionOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.pillHeight = 56,
    this.pillHorizontalMargin = 8,
    this.pillBottomOffset = kBottomNavigationBarHeight + 8,
    this.backMinimizesSession = true,
    this.expandRect,
    this.pillContentBuilder,
  });

  /// Drives the session's lifecycle and the animations the overlay renders.
  final SessionController controller;

  /// Your app shell (e.g. a [Scaffold] with your own navigation). The session
  /// is layered above it.
  final Widget child;

  /// Height of the docked pill.
  final double pillHeight;

  /// Horizontal inset of the pill from the screen edges.
  final double pillHorizontalMargin;

  /// Distance from the bottom edge of the overlay to the bottom of the pill.
  /// Defaults to a standard [BottomNavigationBar] height plus a small gap;
  /// override it to match your own bottom bar. The bottom safe-area inset is
  /// added on top automatically.
  final double pillBottomOffset;

  /// When true, the system back gesture minimizes an expanded session instead
  /// of popping the route (doc §7).
  final bool backMinimizesSession;

  /// The rect the session expands to. Defaults to the full overlay area; supply
  /// a custom rect to expand into a sub-region instead of full screen.
  final Rect? expandRect;

  /// Optional custom builder for the pill's content.
  final Widget Function(BuildContext context, SessionEntry entry)?
      pillContentBuilder;

  Rect _pillRect(Size size, double bottomInset) {
    final top = size.height - bottomInset - pillBottomOffset - pillHeight;
    return Rect.fromLTWH(
      pillHorizontalMargin,
      top,
      size.width - pillHorizontalMargin * 2,
      pillHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final fullRect = expandRect ?? (Offset.zero & size);
        final pillRect = _pillRect(size, bottomInset);

        return AnimatedBuilder(
          // Rebuild only on discrete status transitions; the render layer
          // handles per-frame motion, so animation ticks never rebuild here.
          animation: controller.statusListenable,
          builder: (context, _) {
            final status = controller.status;
            final hasSession = controller.hasSession;
            final expanded = status == SessionStatus.expanded;

            return PopScope(
              canPop: !(backMinimizesSession && expanded),
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && expanded) controller.minimize();
              },
              child: Stack(
                children: [
                  // The user's app shell.
                  Positioned.fill(child: child),

                  // The docked pill, shown only when settled-minimized so the
                  // moving SessionHost owns the screen mid-animation.
                  if (hasSession && status == SessionStatus.minimized)
                    Positioned.fromRect(
                      rect: pillRect,
                      child: MinimizedSessionBar(
                        controller: controller,
                        contentBuilder: pillContentBuilder,
                      ),
                    ),

                  // The persistent session layer: always present while a
                  // session exists, so its State survives minimize/restore.
                  if (hasSession)
                    SessionHost(
                      controller: controller,
                      collapsedRect: pillRect,
                      fullRect: fullRect,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
