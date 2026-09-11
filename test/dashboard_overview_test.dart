// Regression test for the Home dashboard's stat tiles: they must never
// overflow, at any screen width. A previous version pinned each tile to a
// fixed `childAspectRatio`-derived height, which rendered a few pixels
// short of what the content actually needed on desktop/web font metrics
// ("BOTTOM OVERFLOWED BY 4.0 PIXELS"). [DashboardOverview] now sizes each
// tile from its own content instead (see `_StatTileGrid`'s doc comment in
// lib/widgets/dashboard_overview.dart), which makes that class of failure
// structurally impossible — this test pins that behavior down so it stays
// that way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/models/asset.dart';
import 'package:qr_assisted_asset_management/widgets/dashboard_overview.dart';

/// A handful of assets exercising every stat tile and every "Needs
/// attention" row (past lifespan, damaged, low stock) at once, so the test
/// isn't just checking the empty/all-clear state.
List<AssetItem> _sampleAssets() => [
      AssetItem(
        name: 'Projector',
        tagId: 'CSDO-IT-0001',
        category: 'IT Equipment',
        description: '',
        status: AssetStatus.available,
        purchaseDate: DateTime(2024, 1, 1),
      ),
      AssetItem(
        name: 'Laptop',
        tagId: 'CSDO-IT-0002',
        category: 'IT Equipment',
        description: '',
        status: AssetStatus.inUse,
        purchaseDate: DateTime(2024, 1, 1),
      ),
      AssetItem(
        name: 'Aircon',
        tagId: 'CSDO-MT-0003',
        category: 'Tools',
        description: '',
        status: AssetStatus.maintenance,
        purchaseDate: DateTime(2024, 1, 1),
      ),
      AssetItem(
        name: 'Spare chair',
        tagId: 'CSDO-FN-0004',
        category: 'Furniture',
        description: '',
        status: AssetStatus.inStock,
        purchaseDate: DateTime(2024, 1, 1),
      ),
      // Past its category's lifespan.
      AssetItem(
        name: 'Old printer',
        tagId: 'CSDO-IT-0005',
        category: 'IT Equipment',
        description: '',
        status: AssetStatus.available,
        purchaseDate: DateTime(2015, 1, 1),
        lifespanYears: 5,
      ),
      // Returned damaged.
      AssetItem(
        name: 'Dented cart',
        tagId: 'CSDO-FN-0006',
        category: 'Furniture',
        description: '',
        status: AssetStatus.available,
        purchaseDate: DateTime(2024, 1, 1),
        lastConditionRaw: 'damaged',
      ),
      // Bulk pool, low on stock.
      AssetItem(
        name: 'Foldable chairs',
        tagId: 'CSDO-FN-0007',
        category: 'Furniture',
        description: '',
        status: AssetStatus.available,
        purchaseDate: DateTime(2024, 1, 1),
        tracking: AssetTracking.bulk,
        quantityTotal: 20,
        quantityOut: 18,
        reorderPoint: 5,
      ),
    ];

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DashboardOverview(
            assets: _sampleAssets(),
            pendingRequestsCount: 3,
            overdueRequestsCount: 2,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // A representative spread: a narrow phone, a tablet, a laptop, and a
  // wide desktop/browser window — the exact overflow this guards against
  // only showed up at the wider end.
  const sizes = {
    'narrow phone (360x800)': Size(360, 800),
    'tablet (800x1024)': Size(800, 1024),
    'laptop (1280x800)': Size(1280, 800),
    'wide desktop (1920x1080)': Size(1920, 1080),
  };

  for (final entry in sizes.entries) {
    testWidgets('renders without overflow at ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value);
      expect(tester.takeException(), isNull);
    });
  }
}
