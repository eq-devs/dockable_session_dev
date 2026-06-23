import 'package:flutter/widgets.dart';

import 'session_entry.dart';
import 'session_status.dart';

/// Builds a session's full-screen content. Receives the [SessionController]
/// driving it so the content can minimize/close itself without an inherited
/// scope.
typedef SessionContentBuilder = Widget Function(
  BuildContext context,
  SessionController controller,
);

/// Drives the single persistent session's lifecycle and the two animations
/// that render it.
///
/// The controller is the lifecycle hub from `doc.MD` §4. It is a
/// [ChangeNotifier]; the widget layer ([SessionOverlay]) listens
/// and rebuilds. It owns two [AnimationController]s:
///
///  * [expansion] — `0` = collapsed (pill rect), `1` = expanded (full screen).
///    Open/restore drive it forward; minimize drives it in reverse.
///  * [closeProgress] — `0` = present, `1` = closed (fade + slight shrink).
///
/// Keeping both animations here lets minimize/restore reverse from the current
/// progress instead of restarting (doc §6.3): [AnimationController.forward] and
/// [AnimationController.reverse] both continue from the current value.
class SessionController extends ChangeNotifier {
  SessionController({
    required TickerProvider vsync,
    this.openDuration = const Duration(milliseconds: 340),
    this.minimizeDuration = const Duration(milliseconds: 280),
    this.restoreDuration = const Duration(milliseconds: 280),
    this.closeDuration = const Duration(milliseconds: 200),
  }) {
    _expand = AnimationController(vsync: vsync, value: 0)
      ..addListener(notifyListeners)
      ..addStatusListener(_onExpandStatus);
    _close = AnimationController(vsync: vsync, value: 0)
      ..addListener(notifyListeners)
      ..addStatusListener(_onCloseStatus);
  }

  /// Duration of the open (bottom → full) animation.
  final Duration openDuration;

  /// Duration of the minimize (full → pill) animation.
  final Duration minimizeDuration;

  /// Duration of the restore (pill → full) animation.
  final Duration restoreDuration;

  /// Duration of the close (fade + shrink) animation.
  final Duration closeDuration;

  late final AnimationController _expand;
  late final AnimationController _close;

  SessionEntry? _entry;
  SessionStatus _status = SessionStatus.none;

  // Fires only on discrete structural transitions (status/entry changes), never
  // per animation frame. The overlay listens to this so animation ticks don't
  // rebuild it — the render layer handles per-frame motion.
  final _StructureNotifier _structure = _StructureNotifier();

  // Emits a structural change: pings [statusListenable] for the widget layer and
  // also notifies plain [ChangeNotifier] listeners. (Per-frame animation ticks
  // call notifyListeners directly, bypassing _structure.)
  void _emit() {
    _structure.ping();
    notifyListeners();
  }

  // ---- Queries ----

  /// Whether a session currently exists.
  bool get hasSession => _entry != null;

  /// The lifecycle status of the session.
  SessionStatus get status => _status;

  /// Notifies only on discrete status/entry transitions (not per animation
  /// frame). The overlay listens to this so it rebuilds on structural changes,
  /// leaving the per-frame motion to the render layer.
  Listenable get statusListenable => _structure;

  /// The live session entry, or `null` when [hasSession] is false.
  SessionEntry? get entry => _entry;

  /// Expansion animation: `0` = pill, `1` = full screen.
  Animation<double> get expansion => _expand;

  /// Close animation: `0` = present, `1` = closed.
  Animation<double> get closeProgress => _close;

  // ---- Lifecycle ----

  /// Opens a brand-new session and animates it to full screen.
  ///
  /// Throws a [StateError] if a session already exists — use [replace] to swap
  /// the live session.
  void open({required SessionContentBuilder builder, String title = 'Session'}) {
    if (_entry != null) {
      throw StateError(
        'A session already exists. Use replace() to swap it, or close() first.',
      );
    }
    _entry = SessionEntry(builder: builder, title: title);
    _close.value = 0;
    _status = SessionStatus.animating;
    _expand
      ..duration = openDuration
      ..value = 0
      ..forward();
    _emit();
  }

  /// Minimizes the expanded session to its pill. No-op when there is nothing
  /// sensible to minimize.
  void minimize() {
    if (_entry == null || status == SessionStatus.minimized) return;
    _status = SessionStatus.animating;
    _expand.reverseDuration = minimizeDuration;
    _expand.reverse();
    _emit();
  }

  /// Restores the minimized session to full screen. No-op when there is
  /// nothing sensible to restore.
  void restore() {
    if (_entry == null || status == SessionStatus.expanded) return;
    _status = SessionStatus.animating;
    _expand.duration = restoreDuration;
    _expand.forward();
    _emit();
  }

  /// Closes and destroys the session after a short fade + shrink.
  void close() {
    if (_entry == null) return;
    _status = SessionStatus.animating;
    _close
      ..duration = closeDuration
      ..forward(from: 0);
    _emit();
  }

  /// Replaces the live session with a new one, discarding the old session's
  /// `State` (doc §4). The new session keeps the previous expanded/minimized
  /// disposition. If no session exists this behaves like [open].
  void replace({required SessionContentBuilder builder, String title = 'Session'}) {
    if (_entry == null) {
      open(builder: builder, title: title);
      return;
    }
    final keepMinimized = status == SessionStatus.minimized;
    _entry = SessionEntry(builder: builder, title: title);
    _close.value = 0;
    if (keepMinimized) {
      _expand.value = 0;
      _status = SessionStatus.minimized;
    } else {
      _expand.value = 1;
      _status = SessionStatus.expanded;
    }
    _emit();
  }

  void _onExpandStatus(AnimationStatus status) {
    // Only settle expand-driven transitions; a close in flight settles in
    // _onCloseStatus.
    if (_status != SessionStatus.animating || _entry == null) return;
    if (_close.value != 0) return;
    if (status == AnimationStatus.completed) {
      _status = SessionStatus.expanded;
      _emit();
    } else if (status == AnimationStatus.dismissed) {
      _status = SessionStatus.minimized;
      _emit();
    }
  }

  void _onCloseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _entry = null;
    _close.value = 0;
    _expand.value = 0;
    _status = SessionStatus.none;
    _emit();
  }

  @override
  void dispose() {
    _expand.dispose();
    _close.dispose();
    _structure.dispose();
    super.dispose();
  }
}

/// A [ChangeNotifier] whose notification can be triggered directly, used for the
/// controller's structural ([SessionController.statusListenable]) channel.
class _StructureNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
