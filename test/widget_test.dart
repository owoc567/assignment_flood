import 'package:flutter_test/flutter_test.dart';

import 'package:assignment_flood/main.dart';
import 'package:assignment_flood/screens/users/signIn.dart';

void main() {
  testWidgets('Get Started button navigates to SignIn', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MainApp());

    // Verify the Get Started button is present.
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(SignIn), findsNothing);

    // Tap the button and trigger a frame.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify we've navigated to SignIn.
    expect(find.byType(SignIn), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}