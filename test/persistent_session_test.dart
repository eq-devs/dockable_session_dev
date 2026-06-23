import 'package:dockable_session_dev/dockable_session_dev.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [TickerProvider] for driving a [SessionController] in tests.
class _TestVSync implements TickerProvider {
  const _TestVSync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// A stateful counter used to prove that `State` survives minimize/restore.
/// Receives the [SessionController] so its buttons can drive the session
/// without an inherited scope.
class _Counter extends StatefulWidget {
  const _Counter({required this.label, this.controller});
  final String label;
  final SessionController? controller;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.label}:$n'),
            ElevatedButton(
              onPressed: () => setState(() => n++),
              child: Text('inc-${widget.label}'),
            ),
            ElevatedButton(
              onPressed: () => widget.controller?.minimize(),
              child: const Text('min-from-content'),
            ),
            ElevatedButton(
              onPressed: () => widget.controller?.close(),
              child: const Text('close-from-content'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two fixed tabs, hosted in an [IndexedStack] by the test app.
Widget _tabs(int index, ValueChanged<int> onTap) => Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          _Counter(label: 'tab0'),
          _Counter(label: 'tab1'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );

Widget _app(SessionController controller) => MaterialApp(
      home: _TestShell(controller: controller),
    );

/// Minimal host: the user's own Scaffold/nav wrapped in [SessionOverlay].
class _TestShell extends StatefulWidget {
  const _TestShell({required this.controller});
  final SessionController controller;
  @override
  State<_TestShell> createState() => _TestShellState();
}

class _TestShellState extends State<_TestShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    return SessionOverlay(
      controller: widget.controller,
      child: _tabs(_index, (i) => setState(() => _index = i)),
    );
  }
}

/// Counts how many times its subtree is built, to prove the session content is
/// not rebuilt per animation frame.
int _buildCount = 0;

class _BuildCounter extends StatefulWidget {
  const _BuildCounter();
  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    _buildCount++;
    return const SizedBox.expand();
  }
}

void main() {
  late SessionController controller;

  setUp(() => controller = SessionController(vsync: const _TestVSync()));
  tearDown(() => controller.dispose());

  testWidgets('starts with no session', (tester) async {
    await tester.pumpWidget(_app(controller));
    expect(controller.status, SessionStatus.none);
    expect(controller.hasSession, isFalse);
    expect(find.byType(MinimizedSessionBar), findsNothing);
    expect(find.byType(SessionHost), findsNothing);
  });

  testWidgets('open animates to an expanded session', (tester) async {
    await tester.pumpWidget(_app(controller));

    controller.open(builder: (_, c) => _Counter(label: 's', controller: c), title: 'S');
    await tester.pump(); // start of animation
    expect(controller.status, SessionStatus.animating);

    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.expanded);
    expect(controller.expansion.value, 1.0);
    expect(find.text('s:0'), findsOneWidget);
  });

  testWidgets('open throws when a session already exists', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c));
    await tester.pumpAndSettle();
    expect(
      () => controller.open(
        builder: (_, c) => _Counter(label: 't', controller: c),
      ),
      throwsStateError,
    );
  });

  testWidgets('minimize preserves State (the iron rule)', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c), title: 'S');
    await tester.pumpAndSettle();

    // Drive the counter to 3.
    await tester.tap(find.text('inc-s'));
    await tester.tap(find.text('inc-s'));
    await tester.tap(find.text('inc-s'));
    await tester.pump();
    expect(find.text('s:3'), findsOneWidget);

    controller.minimize();
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.minimized);
    expect(find.byType(MinimizedSessionBar), findsOneWidget);

    controller.restore();
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.expanded);
    // If the subtree had been rebuilt instead of kept alive, this would be 0.
    expect(find.text('s:3'), findsOneWidget);
  });

  testWidgets('tapping the pill restores the session', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c), title: 'S');
    await tester.pumpAndSettle();
    controller.minimize();
    await tester.pumpAndSettle();

    await tester.tap(find.text('S')); // pill title
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.expanded);
  });

  testWidgets('minimize and close can be driven from session content',
      (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c), title: 'S');
    await tester.pumpAndSettle();

    // Scope to the session subtree; the (off-screen) tabs contain the same
    // buttons.
    await tester.tap(find.descendant(
      of: find.byType(SessionHost),
      matching: find.text('min-from-content'),
    ));
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.minimized);

    controller.restore();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(SessionHost),
      matching: find.text('close-from-content'),
    ));
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.none);
    expect(controller.hasSession, isFalse);
  });

  testWidgets('close destroys the session', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c));
    await tester.pumpAndSettle();

    controller.close();
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.none);
    expect(controller.hasSession, isFalse);
    expect(find.text('s:0'), findsNothing);
    expect(find.byType(SessionHost), findsNothing);
  });

  testWidgets('replace swaps content and discards old State', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(
      builder: (_, c) => _Counter(label: 'A', controller: c),
      title: 'A',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('inc-A'));
    await tester.pump();
    expect(find.text('A:1'), findsOneWidget);

    controller.replace(
      builder: (_, c) => _Counter(label: 'B', controller: c),
      title: 'B',
    );
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.expanded);
    expect(find.text('B:0'), findsOneWidget);
    expect(find.textContaining('A:'), findsNothing);
  });

  testWidgets('restore mid-minimize settles back to expanded (interruption)',
      (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c));
    await tester.pumpAndSettle();

    controller.minimize();
    await tester.pump(); // start the ticker (establishes t=0)
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight
    expect(controller.status, SessionStatus.animating);
    expect(controller.expansion.value, greaterThan(0.0));
    expect(controller.expansion.value, lessThan(1.0));

    controller.restore();
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.expanded);
    expect(controller.expansion.value, 1.0);
  });

  testWidgets('system back minimizes an expanded session', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.status, SessionStatus.minimized);
  });

  testWidgets('tabs preserve their own state via IndexedStack', (tester) async {
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.text('inc-tab0'));
    await tester.pump();
    expect(find.text('tab0:1'), findsOneWidget);

    // Switch to the Settings tab, then back to Home.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('tab0:1'), findsOneWidget);
  });

  testWidgets('expanded session covers the full screen', (tester) async {
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, c) => _Counter(label: 's', controller: c));
    await tester.pumpAndSettle();

    final hostSize = tester.getSize(find.byType(SessionHost));
    expect(hostSize, tester.getSize(find.byType(SessionOverlay)));
  });

  testWidgets('content is not rebuilt per animation frame (render-layer motion)',
      (tester) async {
    _buildCount = 0;
    await tester.pumpWidget(_app(controller));
    controller.open(builder: (_, __) => const _BuildCounter());
    await tester.pumpAndSettle();

    // Start a minimize; the expanded -> animating transition rebuilds the host
    // (and content) exactly once. After that, frames are pure paint.
    controller.minimize();
    await tester.pump();
    final buildsAtAnimationStart = _buildCount;

    // Several frames mid-animation must not rebuild the content subtree — the
    // render layer animates paint only.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.status, SessionStatus.animating);
    expect(_buildCount, buildsAtAnimationStart);

    await tester.pumpAndSettle();
  });
}
