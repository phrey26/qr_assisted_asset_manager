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

    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('register route is reachable', (tester) async {
    await tester.pumpWidget(const AssetManagementApp());

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    expect(find.text('Create admin account'), findsOneWidget);
  });

  test('login route name is defined', () {
    expect(LoginScreen.routeName, '/login');
  });
}
