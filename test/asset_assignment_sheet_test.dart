// Regression test for the request-approval "assign assets" picker: a
// Maintenance or In-stock asset is never lendable (see
// AssetItem.isActiveInventory) and previously showed up in the picker
// locked with "Already borrowed — free it by cancelling its request" —
// which is false, since neither status means anyone has it out on loan.
// See lib/widgets/asset_assignment_sheet.dart's `_visible` getter and
// `_lockedNote` for the fix this pins down.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/models/asset.dart';
import 'package:qr_assisted_asset_management/models/asset_request.dart';
import 'package:qr_assisted_asset_management/widgets/asset_assignment_sheet.dart';

void main() {
  testWidgets(
    'maintenance/in-stock assets are excluded from the assign-assets '
    'picker instead of showing up locked with a false "already borrowed"',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final assets = [
        AssetItem(
          name: 'Free projector',
          tagId: 'CSDO-IT-0001',
          category: 'IT Equipment',
          description: '',
          status: AssetStatus.available,
          purchaseDate: DateTime(2024, 1, 1),
        ),
        AssetItem(
          name: 'Broken projector',
          tagId: 'CSDO-IT-0002',
          category: 'IT Equipment',
          description: '',
          status: AssetStatus.maintenance,
          purchaseDate: DateTime(2024, 1, 1),
        ),
        AssetItem(
          name: 'Backup projector',
          tagId: 'CSDO-IT-0003',
          category: 'IT Equipment',
          description: '',
          status: AssetStatus.inStock,
          purchaseDate: DateTime(2024, 1, 1),
        ),
      ];

      final request = AssetRequest(
        title: 'Seminar',
        requester: 'Juan Dela Cruz',
        department: 'CICS',
        borrowDate: 'Sep 15, 2026',
        returnDate: 'Sep 15, 2026',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAssetAssignmentPicker(
                    context,
                    assets: assets,
                    request: request,
                  ),
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();

      // The available asset shows up, pickable.
      expect(find.text('Free projector'), findsOneWidget);
      // Maintenance / in-stock assets were never lendable to begin with —
      // they don't belong in a "what can I hand out" list at all, and
      // definitely shouldn't be shown locked with a false reason.
      expect(find.text('Broken projector'), findsNothing);
      expect(find.text('Backup projector'), findsNothing);
      expect(find.textContaining('Already borrowed'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
}
