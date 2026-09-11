// Model tests for the reports.php analytics payload (see
// lib/models/report_data.dart). Each parser is exercised against JSON
// shaped exactly like reports.php's own `json_encode` output.
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/models/report_data.dart';

void main() {
  test('WeekCount.fromJson reads week_start plus a caller-named label/count pair', () {
    final requestRow = WeekCount.fromJson(
      {'week_start': '2026-08-31', 'status': 'approved', 'count': 4},
      labelKey: 'status',
      countKey: 'count',
    );
    expect(requestRow.weekStart, DateTime(2026, 8, 31));
    expect(requestRow.label, 'approved');
    expect(requestRow.count, 4);

    final stockRow = WeekCount.fromJson(
      {'week_start': '2026-08-31', 'direction': 'out', 'units': 12},
      labelKey: 'direction',
      countKey: 'units',
    );
    expect(stockRow.label, 'out');
    expect(stockRow.count, 12);
  });

  test('NamedCount.fromJson reads a caller-named name/count pair', () {
    final statusRow = NamedCount.fromJson(
      {'status': 'available', 'count': 9},
      nameKey: 'status',
      countKey: 'count',
    );
    expect(statusRow.name, 'available');
    expect(statusRow.count, 9);

    final deptRow = NamedCount.fromJson(
      {'department': 'Registrar', 'count': 3},
      nameKey: 'department',
      countKey: 'count',
    );
    expect(deptRow.name, 'Registrar');
    expect(deptRow.count, 3);
  });

  test('TopBorrowedAsset.fromJson parses every field, category nullable', () {
    final withCategory = TopBorrowedAsset.fromJson({
      'tag_id': 'CSDO-IT-0001',
      'name': 'Projector',
      'category': 'IT Equipment',
      'times_borrowed': 7,
    });
    expect(withCategory.tagId, 'CSDO-IT-0001');
    expect(withCategory.name, 'Projector');
    expect(withCategory.category, 'IT Equipment');
    expect(withCategory.timesBorrowed, 7);

    final withoutCategory = TopBorrowedAsset.fromJson({
      'tag_id': 'CSDO-IT-0002',
      'name': 'Laptop',
      'category': null,
      'times_borrowed': 1,
    });
    expect(withoutCategory.category, isNull);
  });

  test('ReportsBundle.fromJson assembles all five sections from one payload', () {
    final bundle = ReportsBundle.fromJson({
      'requests_by_week': [
        {'week_start': '2026-08-31', 'status': 'approved', 'count': 4},
        {'week_start': '2026-08-31', 'status': 'pending', 'count': 2},
      ],
      'status_breakdown': [
        {'status': 'available', 'count': 9},
        {'status': 'in_use', 'count': 3},
      ],
      'top_assets': [
        {'tag_id': 'CSDO-IT-0001', 'name': 'Projector', 'category': 'IT Equipment', 'times_borrowed': 7},
      ],
      'department_demand': [
        {'department': 'Registrar', 'count': 3},
      ],
      'stock_movement_summary': [
        {'week_start': '2026-08-31', 'direction': 'in', 'units': 20},
        {'week_start': '2026-08-31', 'direction': 'out', 'units': 8},
      ],
    });

    expect(bundle.requestsByWeek, hasLength(2));
    expect(bundle.statusBreakdown, hasLength(2));
    expect(bundle.topAssets, hasLength(1));
    expect(bundle.departmentDemand, hasLength(1));
    expect(bundle.stockMovementSummary, hasLength(2));
    expect(bundle.isEmpty, isFalse);
  });

  test('ReportsBundle.fromJson tolerates missing keys and reports isEmpty', () {
    final bundle = ReportsBundle.fromJson(const {});
    expect(bundle.requestsByWeek, isEmpty);
    expect(bundle.statusBreakdown, isEmpty);
    expect(bundle.topAssets, isEmpty);
    expect(bundle.departmentDemand, isEmpty);
    expect(bundle.stockMovementSummary, isEmpty);
    expect(bundle.isEmpty, isTrue);
  });

  test('ReportsBundle.isEmpty is false when even one section has data', () {
    final bundle = ReportsBundle.fromJson({
      'status_breakdown': [
        {'status': 'available', 'count': 1},
      ],
    });
    expect(bundle.isEmpty, isFalse);
  });
}
