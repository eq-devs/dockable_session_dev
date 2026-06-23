/// The lifecycle state of the single persistent session.
///
/// There is at most one session at any time, so this also describes the state
/// of the whole framework. See the state machine in the package `doc.MD`.
enum SessionStatus {
  /// No session exists.
  none,

  /// A session exists and is shown full-screen.
  expanded,

  /// A session exists, is docked as a pill, and is kept alive off-screen
  /// (via `Offstage`) with its `State` fully preserved.
  minimized,

  /// A session is mid-transition between two of the states above.
  ///
  /// This is the key intermediate state: while `animating`, conflicting
  /// requests (e.g. restoring during a minimize) reverse the in-flight
  /// animation from its current progress rather than restarting it.
  animating,
}
