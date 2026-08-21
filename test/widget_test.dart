import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_manager/main.dart';

void main() {
  testWidgets(
    'CSDO Asset Manager loads successfully',
    (WidgetTester tester) async {
      // Start the application.
      await tester.pumpWidget(
        const CSDOAssetManager(),
      );

      // Allow the initial frame to render.
      await tester.pumpAndSettle();

      // Verify that the application loaded.
      expect(
        find.text('CSDO Asset System'),
        findsOneWidget,
      );

      // Verify that the bottom navigation exists.
      expect(
        find.text('Dashboard'),
        findsOneWidget,
      );

      expect(
        find.text('Inventory'),
        findsOneWidget,
      );

      expect(
        find.text('Scan'),
        findsOneWidget,
      );

      expect(
        find.text('Requests'),
        findsOneWidget,
      );

      expect(
        find.text('More'),
        findsOneWidget,
      );
    },
  );
}