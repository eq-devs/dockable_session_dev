import 'package:flutter/widgets.dart';

import 'session_controller.dart';

/// The data backing the single live session.
///
/// The owning [SessionController] holds at most one of these at a time. The
/// entry is intentionally light: the heavy state (scroll positions, text
/// fields, WebView, ...) lives inside the widget subtree built by [builder],
/// which stays mounted for the entry's whole life so that `State` survives
/// minimize/restore.
class SessionEntry {
  SessionEntry({
    required this.builder,
    this.title = 'Session',
    this.keepAlive = true,
  })  : navigatorKey = GlobalKey<NavigatorState>(),
        contentKey = UniqueKey(),
        createdAt = DateTime.now();

  /// Builds the session's full-screen content. Receives the controller driving
  /// the session.
  final SessionContentBuilder builder;

  /// Human-readable label shown on the minimized pill.
  final String title;

  /// Optional key for an app-managed nested [Navigator] so a session can keep
  /// its own back stack isolated from the host app. Provided as a hook; the
  /// framework does not wire a Navigator for you.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Stable identity of this entry's subtree. A new entry gets a new key so
  /// that replacing the session disposes the previous subtree's `State`.
  final Key contentKey;

  /// When the entry was created.
  final DateTime createdAt;

  /// Whether the subtree should be kept alive while minimized. Always true in
  /// the current framework; exposed for clarity and future use.
  bool keepAlive;

  // ---- WebView / memory-pressure fallback (doc §5, §8) ----

  /// Last known URL of a URL-backed session, used to rebuild after the OS
  /// reclaims a native WebView.
  String? lastUrl;

  /// Last known scroll offset, used to restore close to the original state.
  double? scrollOffset;

  /// Opaque handle to a native WebView controller, if any. Typed as [Object?]
  /// so the framework carries no WebView dependency.
  Object? webViewController;
}
