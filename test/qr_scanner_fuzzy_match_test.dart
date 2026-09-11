// Widget-level regression test for the QR scanner's fuzzy fallback: when
// manually-entered text doesn't match any tag exactly, it should fall back
// to a name/tag substring search instead of dead-ending at "No asset
// found" — and offer a pick list when more than one asset matches. See
// lib/screens/qr_scanner_screen.dart's `_handleTag`/`_openMatches`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/models/asset.dart';
import 'package:qr_assisted_asset_management/screens/qr_scanner_screen.dart';

void main() {
  testWidgets(
    'manual entry with no exact tag match falls back to a fuzzy pick list, '
    'and picking one opens its full scan result',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final assets = [
        AssetItem(
          name: 'Epson projector',
          tagId: 'CSDO-IT-0231',
          category: 'IT Equipment',
          description: '',
          status: AssetStatus.available,
          purchaseDate: DateTime(2024, 1, 1),
        ),
        AssetItem(
          name: 'Epson printer',
          tagId: 'CSDO-IT-0450',
          category: 'IT Equipment',
          description: '',
          status: AssetStatus.available,
          purchaseDate: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          // isActive: false — never mounts the live camera preview, only
          // the manual tag-entry path this test exercises. Its idle
          // placeholder has an indeterminate CircularProgressIndicator,
          // which animates forever — pumpAndSettle would never return on
          // this screen, so every step below uses a bounded pump instead.
          home: Scaffold(body: QrScannerScreen(assets: assets, isActive: false)),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Epson');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      // A route pushed from inside an async callback needs a plain pump
      // first to actually land in the tree — jumping straight to a
      // duration-based pump can miss it — then a duration-based one for
      // MaterialPageRoute's 300ms-default push transition to finish.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Possible matches'), findsOneWidget);
      expect(find.text('Epson projector'), findsOneWidget);
      expect(find.text('Epson printer'), findsOneWidget);

      await tester.tap(find.text('Epson projector'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Scan result'), findsOneWidget);
      expect(find.text('Epson projector'), findsWidgets);
      expect(find.text('No asset found'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
}
