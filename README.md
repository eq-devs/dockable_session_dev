# dockable_session_dev

A Flutter framework for a **single persistent, minimizable session** — Telegram /
Chrome Custom Tab behavior for any page.

Any page can open as the one live *session*, expand to full screen, dock to a
**pill** above the bottom navigation bar, and restore at any time — all while
keeping its `State` fully alive. The session **never leaves the widget tree**;
minimizing only flips `Offstage`, so scroll positions, text fields, and
controllers survive untouched. There is at most one session at a time, driven
entirely by buttons / taps — no drag gestures.

See [`doc.MD`](doc.MD) for the full design.

## Install

```yaml
dependencies:
  dockable_session_dev: ^0.1.0
```

## Usage

`SessionOverlay` is unopinionated about navigation: build your own `Scaffold`,
tabs, and bottom bar, and stack the session on top with a `SessionController`
you own.

```dart
final controller = SessionController(vsync: this); // a TickerProvider

SessionOverlay(
  controller: controller,
  child: Scaffold(
    body: myTabs,                      // your own UI
    bottomNavigationBar: myNavBar,
  ),
);
```

Drive the session from anywhere with the controller:

```dart
controller.open(builder: (_, c) => ArticlePage(), title: 'Article');
controller.minimize();   // docks to the pill, State preserved
controller.restore();    // back to full screen
controller.close();      // destroys the session
controller.replace(builder: (_, c) => OtherPage(), title: 'Other'); // swap content
```

A session's content receives the controller as the builder's second argument —
no inherited scope — so it can drive its own lifecycle:

```dart
controller.open(
  builder: (context, controller) => IconButton(
    icon: const Icon(Icons.remove),
    onPressed: controller.minimize,
  ),
);
```

## How state survives

The session widget is always mounted while it exists. Minimizing wraps it in
`Offstage` (zero-size, unpainted, unhittable, but `State` lives) and
`TickerMode(enabled: false)` to freeze its animations while docked. Restoring
just flips those back. This is the framework's one iron rule: **a minimized
session must not leave the tree.**

## API

- **`SessionOverlay`** — stacks the animating session + docked pill over your
  own app (`child`); owns the rect interpolation, layering, and
  back-button-to-minimize. Configurable pill geometry and an optional
  `expandRect` for non-fullscreen sessions.
- **`SessionController`** — `open` / `minimize` / `restore` / `close` /
  `replace`; `status`, `hasSession`, `entry`, `expansion`, `closeProgress`.
- **`SessionContentBuilder`** — `(BuildContext, SessionController)`; the content
  builder signature passed to `open` / `replace`.
- **`SessionStatus`** — `none`, `expanded`, `minimized`, `animating`.
- **`SessionEntry`** — the live session's data, including WebView fallback
  fields (`lastUrl`, `scrollOffset`, `webViewController`).
- **`SessionHost`** / **`MinimizedSessionBar`** — the rectangle-animating host
  and the pill.

## Example

A runnable demo lives in [`example/`](example/lib/main.dart): tabs, three kinds
of session (article, chat, a WebView stub), minimize/restore via pill and app
bar, and back-button-to-minimize.

## License

MIT
