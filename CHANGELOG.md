## 0.0.2

- Perf: `SessionHost` wraps `SessionTransform` and its content in
  `RepaintBoundary`s so per-frame animation paint no longer flows into the
  host app shell, and the content subtree rasterizes once per frame instead
  of repainting during motion.
- Perf: `SessionHost` caches the built content widget per `SessionEntry`, so
  structural rebuilds (minimize/restore) skip re-diffing the content subtree.
- `SessionController` no longer wires its animations to `notifyListeners`
  per frame — it now notifies only on discrete lifecycle transitions, same
  as `statusListenable`. Listen to `expansion`/`closeProgress` directly for
  per-frame values.

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
