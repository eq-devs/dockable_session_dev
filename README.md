# dockable_session_dev

A Flutter framework for a **single persistent, minimizable session** — open any
page as a live overlay, dock it to a pill, and restore it with its state intact.

Any page can open as the one live *session*, expand to full screen, dock to a
**pill** above the bottom navigation bar, and restore at any time — all while
keeping its `State` fully alive. The session **never leaves the widget tree**;
minimizing only flips `Offstage`, so scroll positions, text fields, and
controllers survive untouched. There is at most one session at a time, driven
entirely by buttons / taps — no drag gestures.

## Features

- **State-preserving minimize/restore** — the session stays mounted; minimizing
  only hides it (`Offstage` + frozen `TickerMode`), so nothing is rebuilt or lost.
- **Unopinionated** — bring your own `Scaffold`, tabs, and bottom bar. The
  overlay only owns the session machinery, not your navigation.
- **Smooth, cheap animation** — open/minimize/restore/close run entirely at the
  render layer; the session content is built **once**, never per frame.
- **Controller-driven** — no gestures, no globals. You own a `SessionController`
  and pass it where you need it.
- **Zero dependencies** — pure Flutter SDK.

## Install

```yaml
dependencies:
  dockable_session_dev: ^0.0.1
```

## Quick start

`SessionController.vsync` needs a `TickerProvider`, so own the controller from a
`State` that mixes in `TickerProviderStateMixin`, and dispose it.

```dart
import 'package:dockable_session_dev/dockable_session_dev.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late final _controller = SessionController(vsync: this);
  int _tab = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build your own app shell; the overlay stacks the session on top of it.
    return SessionOverlay(
      controller: _controller,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () => _controller.open(
                  title: 'Article',
                  builder: (context, controller) => const ArticlePage(),
                ),
                child: const Text('Open session'),
              ),
            ),
            const Center(child: Text('Another tab')),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
          ],
        ),
      ),
    );
  }
}
```

## Driving the session

Call these on the controller from anywhere that holds it:

```dart
controller.open(builder: (_, c) => ArticlePage(), title: 'Article'); // open + expand
controller.minimize();   // dock to the pill, State preserved
controller.restore();    // back to full screen
controller.close();      // fade out and destroy
controller.replace(builder: (_, c) => OtherPage(), title: 'Other'); // swap content
```

- `open` throws a `StateError` if a session already exists — use `replace` to
  swap the live one (it discards the old session's `State`).
- `minimize` / `restore` reverse smoothly from the current progress if you
  interrupt them mid-flight (e.g. restore halfway through a minimize).

## Session content

The content builder's second argument is the controller, so a page can drive its
own lifecycle without any inherited scope:

```dart
controller.open(
  title: 'Article',
  builder: (context, controller) => Scaffold(
    appBar: AppBar(
      title: const Text('Article'),
      actions: [
        IconButton(icon: const Icon(Icons.remove), onPressed: controller.minimize),
        IconButton(icon: const Icon(Icons.close), onPressed: controller.close),
      ],
    ),
    body: const ArticleBody(),
  ),
);
```

## Configuring the overlay

| Parameter | Default | Purpose |
|---|---|---|
| `pillHeight` | `56` | Height of the docked pill. |
| `pillHorizontalMargin` | `8` | Pill inset from the screen edges. |
| `pillBottomOffset` | `kBottomNavigationBarHeight + 8` | Distance from the bottom edge to the pill's bottom. Set this to your bottom bar's height; the safe-area inset is added automatically. |
| `backMinimizesSession` | `true` | System back gesture minimizes an expanded session instead of popping the route. |
| `expandRect` | `null` (full screen) | Expand the session into a sub-region instead of full screen. |
| `pillContentBuilder` | default pill | `(BuildContext, SessionEntry)` to render custom pill content. |

## How state survives

The session widget is always mounted while it exists. Minimizing wraps it in
`Offstage` (zero-size, unpainted, unhittable, but `State` lives) and
`TickerMode(enabled: false)` to freeze its animations while docked. Restoring
just flips those back. This is the framework's one iron rule: **a minimized
session must not leave the tree.**

## Performance

The open/minimize/restore/close motion runs at the **render layer**. A custom
render object listens to the controller's animations and only repaints — it never
rebuilds or relays out the session subtree. The content is built once and the
overlay rebuilds only on discrete status transitions (via
`controller.statusListenable`), so animation frames don't touch the widget tree
at all — even a heavy list, chat, or WebView session stays smooth.

## Lifecycle

`SessionController.status` is one of `SessionStatus`:

| Status | Meaning |
|---|---|
| `none` | No session exists. |
| `expanded` | A session is shown full screen. |
| `minimized` | A session is docked as a pill, kept alive off-screen. |
| `animating` | Mid-transition; interrupting requests reverse the in-flight animation. |

## API

- **`SessionOverlay`** — stacks the animating session + docked pill over your
  own app (`child`); owns the rect interpolation, layering, and
  back-button-to-minimize.
- **`SessionController`** — `open` / `minimize` / `restore` / `close` /
  `replace`; `status`, `hasSession`, `entry`, `expansion`, `closeProgress`,
  `statusListenable`. Configurable `openDuration` / `minimizeDuration` /
  `restoreDuration` / `closeDuration`.
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
