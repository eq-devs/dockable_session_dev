## 0.0.1

- Initial release of the persistent session framework.
- `SessionOverlay` — unopinionated overlay that stacks the animating session +
  docked pill over your own app, owning the rect interpolation, layering, and
  back-button-to-minimize.
- `SessionController` — single-session state machine (`open` / `minimize` /
  `restore` / `close` / `replace`) with rectangle-interpolation animations and
  mid-flight interruption handling.
- `SessionHost` — keeps the session mounted and preserves `State` across
  minimize/restore via `Offstage` + `TickerMode`.
- `RenderSessionTransform` — drives the open/minimize/restore/close motion at the
  render layer: content builds once and only paint updates per frame (no per-tick
  widget rebuilds). The controller's `statusListenable` keeps widget rebuilds to
  discrete status transitions.
- `MinimizedSessionBar`, `SessionEntry` (with WebView fallback fields),
  `SessionContentBuilder`, and `SessionStatus`.
