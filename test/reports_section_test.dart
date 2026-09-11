// Regression tests for the Home dashboard's "Reports" charts
// (lib/widgets/reports_section.dart). Every chart here is hand-built from
// plain Container/Expanded sizing rather than a charting package (see that
// file's doc comment for why), so this pins down the two failure modes that
// approach is most at risk of:
//   - the stacked weekly bars (Column of Expanded segments, sized off a
//     LayoutBuilder-free fixed area height) overflowing or throwing at any
//     screen width, and
//   - a chart card with no data for its section rendering a sane empty
//     state instead of an empty/broken chart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/models/report_data.dart';
import 'package:qr_assisted_asset_management/widgets/reports_section.dart';

/// Exercises every card with realistic, varied data: several weeks of
/// requests split across multiple statuses (including a week with only one
/// status present, to prove missing labels default to a skipped segment
/// rather than a zero-flex crash), a full asset status breakdown, several
/// top-borrowed assets (one with a long name, to exercise the label
/// ellipsis), department demand, and a stock trend with both directions.
ReportsBundle _sampleBundle() => ReportsBundle.fromJson({
  'requests_by_week': [
    {'week_start': '2026-08-17', 'status': 'approved', 'count': 3},
    {'week_start': '2026-08-17', 'status': 'pending', 'count': 1},
    {'week_start': '2026-08-24', 'status': 'approved', 'count': 2},
    {'week_start': '2026-08-31', 'status': 'checked_out', 'count': 5},
    {'week_start': '2026-08-31', 'status': 'rejected', 'count': 1},
  ],
  'status_breakdown': [
    {'status': 'available', 'count': 12},
    {'status': 'in_use', 'count': 6},
    {'status': 'maintenance', 'count': 2},
    {'status': 'in_stock', 'count': 4},
  ],
  'top_assets': [
    {
      'tag_id': 'CSDO-IT-0001',
      'name': 'Wireless Presentation Microphone Set',
      'category': 'IT Equipment',
      'times_borrowed': 14,
    },
    {'tag_id': 'CSDO-IT-0002', 'name': 'Laptop', 'category': 'IT Equipment', 'times_borrowed': 9},
    {'tag_id': 'CSDO-FN-0003', 'name': 'Folding table', 'category': 'Furniture', 'times_borrowed': 3},
  ],
  'department_demand': [
    {'department': 'Registrar', 'count': 11},
    {'department': 'College of Engineering', 'count': 7},
    {'department': 'Student Affairs', 'count': 2},
  ],
  'stock_movement_summary': [
    {'week_start': '2026-08-17', 'direction': 'in', 'units': 20},
    {'week_start': '2026-08-24', 'direction': 'out', 'units': 5},
    {'week_start': '2026-08-31', 'direction': 'in', 'units': 10},
    {'week_start': '2026-08-31', 'direction': 'out', 'units': 8},
  ],
});

Future<void> _pumpAt(WidgetTester tester, Size size, ReportsBundle bundle) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ReportsChartsView(bundle: bundle)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const sizes = {
    'narrow phone (360x800)': Size(360, 800),
    'tablet (800x1024)': Size(800, 1024),
    'laptop (1280x800)': Size(1280, 800),
    'wide desktop (1920x1080)': Size(1920, 1080),
  };

  for (final entry in sizes.entries) {
    testWidgets('full charts view renders without overflow at ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value, _sampleBundle());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders a chart card per section title', (tester) async {
    await _pumpAt(tester, const Size(1280, 900), _sampleBundle());
    expect(find.text('Requests per week'), findsOneWidget);
    expect(find.text('Stock movement'), findsOneWidget);
    expect(find.text('Asset status breakdown'), findsOneWidget);
    expect(find.text('Top borrowed assets'), findsOneWidget);
    expect(find.text('Department demand'), findsOneWidget);
  });

  testWidgets('a section with no data shows the empty note instead of a broken chart', (
    tester,
  ) async {
    final bundle = ReportsBundle.fromJson({
      'status_breakdown': [
        {'status': 'available', 'count': 5},
      ],
      // Every other section left absent -> parses to an empty list.
    });
    await _pumpAt(tester, const Size(1280, 900), bundle);
    expect(tester.takeException(), isNull);
    // 4 of the 5 cards (everything but status breakdown) have nothing to
    // chart.
    expect(find.text('No data yet.'), findsNWidgets(4));
  });

  testWidgets('a week with only one status present renders without throwing', (tester) async {
    // A single-segment stacked bar (Column with exactly one Expanded child)
    // is the edge case the flex-based stacking is most likely to trip on.
    final bundle = ReportsBundle.fromJson({
      'requests_by_week': [
        {'week_start': '2026-08-31', 'status': 'pending', 'count': 1},
      ],
    });
    await _pumpAt(tester, const Size(360, 800), bundle);
    expect(tester.takeException(), isNull);
    expect(find.text('Pending'), findsOneWidget);
  });
}
