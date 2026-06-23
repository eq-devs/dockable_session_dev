/// A Flutter framework for a single persistent, minimizable session.
///
/// Any page can open as the one live "session", expand to full screen, dock to
/// a pill above the bottom navigation bar, and restore — all while keeping its
/// `State` fully alive (it never leaves the widget tree; minimizing only flips
/// `Offstage`). See `doc.MD` for the full design.
///
/// Entry points: [SessionOverlay] (stacks the session over your own app) and
/// [SessionController] (open / minimize / restore / close / replace).
library;

export 'src/minimized_session_bar.dart';
export 'src/session_controller.dart';
export 'src/session_entry.dart';
export 'src/session_host.dart';
export 'src/session_overlay.dart';
export 'src/session_status.dart';
