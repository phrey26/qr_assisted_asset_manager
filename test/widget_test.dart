import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/main.dart';
import 'package:qr_assisted_asset_management/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const AssetManagementApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Employee ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('login opens inventory shell', (tester) async {
    await tester.pumpWidget(const AssetManagementApp());

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    // The active tab's content lives inside the IndexedStack. Scope the
    // search there so we don't also match the bottom-nav / sidebar labels,
    // which share the same words as the page titles.
    final content = find.byType(IndexedStack);
    expect(
      find.descendant(of: content, matching: find.text('Inventory')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: content, matching: find.text('Categories')),
      findsOneWidget,
    );
  });

  testWidgets('register route is reachable', (tester) async {
    await tester.pumpWidget(const AssetManagementApp());

    // "Register" is a TextSpan inside a RichText, not a plain Text widget,
    // so it needs findRichText: true to be located by the text finder.
    await tester.tap(find.text('Register', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Create admin account'), findsOneWidget);
  });

  test('login route name is defined', () {
    expect(LoginScreen.routeName, '/login');
  });
}