import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:employa/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const EmployaApp());
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
  });
}
