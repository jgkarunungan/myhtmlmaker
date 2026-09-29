import 'package:flutter_test/flutter_test.dart';
import 'package:myhtmlmaker/app/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Verify that Module Studio header is present.
    expect(find.text('Module Studio'), findsOneWidget);
  });
}
