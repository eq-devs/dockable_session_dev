import 'package:dockable_session_dev/dockable_session_dev.dart';
import 'package:dockable_session_dev_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('open → minimize → restore round-trip through the example UI',
      (tester) async {
    await tester.pumpWidget(const DemoApp());

    // Open the Chat session from the launcher.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionHost), findsOneWidget);
    expect(find.text('Chat (1)'), findsOneWidget);

    // Minimize via the session app bar.
    await tester.tap(find.byTooltip('Minimize'));
    await tester.pumpAndSettle();
    expect(find.byType(MinimizedSessionBar), findsOneWidget);

    // Restore by tapping the pill, then close it.
    await tester.tap(find.byType(MinimizedSessionBar));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(MinimizedSessionBar), findsNothing);
    expect(find.byType(SessionHost), findsNothing);
  });
}
