import 'package:flutter_test/flutter_test.dart';

import 'package:secure_screenshot/main.dart';

void main() {
  testWidgets('shows the security warning when the device fails the root check', (tester) async {
    await tester.pumpWidget(const MyApp(isSecure: false));

    expect(
      find.textContaining('Device security check failed'),
      findsOneWidget,
    );
  });
}
