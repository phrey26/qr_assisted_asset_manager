import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/main.dart';
import 'package:qr_assisted_asset_management/models/asset.dart';
import 'package:qr_assisted_asset_management/models/asset_request.dart';
import 'package:qr_assisted_asset_management/models/availability.dart';
import 'package:qr_assisted_asset_management/screens/edit_profile_screen.dart';
import 'package:qr_assisted_asset_management/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // _RootGate reads SharedPreferences on startup to decide whether a
    // session is already saved; an empty store sends it to the login screen.
    SharedPreferences.setMockInitialValues({});
  });

  // The default test viewport (800x600 logical, DPR 3.0) forces the mobile
  // login layout, whose fixed design canvas overflows by a hair — invisible
  // in the app (a FittedBox clips it) but a failure under flutter_test.
  // Pin DPR to 1.0 and a wide surface so the scrollable desktop auth layout
  // is used instead. Reset afterwards.
  Future<void> pumpAuthApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const AssetManagementApp());
    await tester.pumpAndSettle();
  }

  testWidgets('login screen renders with email-or-ID field', (tester) async {
    await pumpAuthApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email or Employee ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('empty login shows a validation message', (tester) async {
    await pumpAuthApp(tester);

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(
      find.textContaining('email (or employee ID) and password'),
      findsOneWidget,
    );
  });

  testWidgets('register route is reachable', (tester) async {
    await pumpAuthApp(tester);

    // The "Register" link is a TextSpan inside a RichText whose full text is
    // "Need an account? Register", so match on the containing phrase.
    await tester.tap(find.textContaining('Need an account?', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Create admin account'), findsOneWidget);
  });

  testWidgets('forgot password route is reachable', (tester) async {
    await pumpAuthApp(tester);

    await tester.tap(find.text('Forgot password?').first);
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset code'), findsOneWidget);
  });

  testWidgets('register rejects a non Gmail/Yahoo/Outlook email', (tester) async {
    await pumpAuthApp(tester);
    await tester.tap(find.textContaining('Need an account?', findRichText: true));
    await tester.pumpAndSettle();

    // Fields, in order: Full name, Work email, Department, Employee ID, Password.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'someone@example.com');
    await tester.enterText(fields.at(2), 'CSDO');
    await tester.enterText(fields.at(3), 'EMP-1');
    await tester.enterText(fields.at(4), 'password123');

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(
      find.text('Please use a Gmail, Yahoo, or Outlook email address.'),
      findsOneWidget,
    );
  });

  testWidgets('edit profile prefills fields and locks employee ID', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(
      home: EditProfileScreen(user: {
        'employee_id': 'EMP-42',
        'full_name': 'Ada Admin',
        'department': 'CSDO',
        'email': 'ada@gmail.com',
        'email_verified': 1,
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ada Admin'), findsOneWidget);
    expect(find.text('ada@gmail.com'), findsOneWidget);
    expect(find.text('EMP-42'), findsOneWidget);
    expect(find.text("Employee ID can't be changed."), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  test('login route name is defined', () {
    expect(LoginScreen.routeName, '/login');
  });

  test('new asset payload carries no client-chosen tag_id; backend allocates it', () {
    final draft = AssetItem(
      name: 'Epson projector',
      tagId: '', // the form leaves this empty — csdo_api/assets.php assigns it
      category: 'IT equipment',
      description: '',
      status: AssetStatus.available,
      purchaseDate: DateTime(2024),
    );

    // The POST body must not include tag_id — the backend ignores any client
    // value and hands the real one back in its response.
    expect(draft.toJson().containsKey('tag_id'), isFalse);

    // The caller stamps the backend-allocated tag onto the local asset.
    final saved = draft.copyWith(tagId: 'CSDO-IT-0042');
    expect(saved.tagId, 'CSDO-IT-0042');
    expect(saved.name, draft.name);
  });

  test('isPastLifespan follows the category lifespan, not a hard-coded category', () {
    AssetItem asset({
      required int purchaseYear,
      int? lifespanYears,
      AssetTracking tracking = AssetTracking.individual,
    }) =>
        AssetItem(
          name: 'Thing',
          tagId: 'CSDO-XX1-0001',
          category: 'Anything',
          description: '',
          status: AssetStatus.available,
          purchaseDate: DateTime(purchaseYear, 1, 1),
          tracking: tracking,
          quantityTotal: tracking == AssetTracking.bulk ? 10 : null,
          lifespanYears: lifespanYears,
        );

    final old = DateTime.now().year - 8;
    final recent = DateTime.now().year - 1;

    // A category with a lifespan flags its aged assets...
    expect(asset(purchaseYear: old, lifespanYears: 5).isPastLifespan, isTrue);
    // ...but not ones still within it.
    expect(asset(purchaseYear: recent, lifespanYears: 5).isPastLifespan, isFalse);
    // No lifespan on the category => never flagged, however old.
    expect(asset(purchaseYear: old, lifespanYears: null).isPastLifespan, isFalse);
    // Bulk pools are never flagged.
    expect(
      asset(purchaseYear: old, lifespanYears: 5, tracking: AssetTracking.bulk)
          .isPastLifespan,
      isFalse,
    );
  });

  test('editJson carries only editable fields and the derived custody fields '
      'round-trip through fromJson', () {
    final asset = AssetItem.fromJson({
      'name': 'Epson projector',
      'tag_id': 'CSDO-IT1-0007',
      'category_value': 'IT Equipment',
      'description': 'Room projector',
      'status': 'in_use',
      'purchase_date': '2022-05-01',
      'home_location': 'AVR Room',
      'custodian': 'J. Cruz',
      'last_location': 'Library A/V closet',
      'last_scanned_at': '2025-09-10 14:45:00',
      'current_holder': 'Maria Santos',
      'current_holder_department': 'CSDO',
      'due_back': '2025-09-20',
    });

    expect(asset.homeLocation, 'AVR Room');
    expect(asset.custodian, 'J. Cruz');
    expect(asset.lastLocation, 'Library A/V closet');
    expect(asset.lastScannedAt, isNotNull);
    expect(asset.currentHolder, 'Maria Santos');
    expect(asset.dueBack, '2025-09-20');

    final body = asset.editJson();
    expect(body['action'], 'edit');
    expect(body['tag_id'], 'CSDO-IT1-0007');
    expect(body['home_location'], 'AVR Room');
    expect(body['custodian'], 'J. Cruz');
    // Never editable through this path.
    expect(body.containsKey('status'), isFalse);
    expect(body.containsKey('tracking'), isFalse);
    // Individual asset: no reorder point in the edit body.
    expect(body.containsKey('reorder_point'), isFalse);
  });

  test('AssetRequest carries a machine-comparable loan window through JSON', () {
    // From the backend (GET): borrow_on / return_on are ISO date strings.
    final loaded = AssetRequest.fromJson({
      'id': 7,
      'title': 'ICT week seminar',
      'requester': 'Juan Dela Cruz',
      'department': 'CICS',
      'venue': 'CICS Function Hall',
      'borrow_date': 'Sep 15, 2026',
      'return_date': 'Sep 16, 2026',
      'borrow_on': '2026-09-15',
      'return_on': '2026-09-16',
      'status': 'pending',
      'logistics': [
        {'name': 'Foldable chairs', 'quantity': 120, 'category_id': 2,
         'category_value': 'Furniture'},
      ],
      'equipment': [
        {'name': 'Projector', 'quantity': 1},
      ],
    });

    expect(loaded.borrowOn, DateTime(2026, 9, 15));
    expect(loaded.returnOn, DateTime(2026, 9, 16));
    expect(loaded.logistics.single.categoryId, 2);
    expect(loaded.logistics.single.categoryValue, 'Furniture');
    expect(loaded.logistics.single.isLinked, isTrue);
    expect(loaded.equipment.single.isLinked, isFalse);

    // Round-trips back out as the ISO strings the backend / availability.php
    // expect, plus the category link on each line.
    final body = loaded.toJson();
    expect(body['borrow_on'], '2026-09-15');
    expect(body['return_on'], '2026-09-16');
    expect((body['logistics'] as List).single['category_id'], 2);
    expect((body['equipment'] as List).single.containsKey('category_id'), isFalse);

    expect(AssetRequest.isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    expect(AssetRequest.isoDate(null), isNull);

    // Legacy row with no comparable dates: window is just null, not a crash.
    final legacy = AssetRequest.fromJson({
      'id': 1,
      'title': 'Old request',
      'requester': 'X',
      'department': 'Y',
      'borrow_date': 'sometime',
      'return_date': 'later',
      'status': 'pending',
    });
    expect(legacy.borrowOn, isNull);
    expect(legacy.returnOn, isNull);
  });

  test('RequestStatus.checkedOut maps to/from the backend "checked_out" slug', () {
    expect(RequestStatus.checkedOut.apiValue, 'checked_out');
    expect(RequestStatus.approved.apiValue, 'approved');
    expect(RequestStatusApiX.fromApiValue('checked_out'), RequestStatus.checkedOut);
    expect(RequestStatusApiX.fromApiValue('approved'), RequestStatus.approved);
    expect(RequestStatus.checkedOut.label, 'Checked out');

    final r = AssetRequest.fromJson({
      'id': 9,
      'title': 'T',
      'requester': 'R',
      'department': 'D',
      'borrow_date': 'Sep 15, 2026',
      'return_date': 'Sep 16, 2026',
      'status': 'checked_out',
    });
    expect(r.status, RequestStatus.checkedOut);
  });

  test('WindowAvailabilityReport parses per-asset free counts and conflicts', () {
    final report = WindowAvailabilityReport.fromJson({
      'from': '2026-09-15',
      'to': '2026-09-16',
      'assets': [
        {
          'tag_id': 'CSDO-FU2-0001',
          'tracking': 'bulk',
          'window_committed': 30,
          'window_free': 90,
          'available_now': 120,
          'conflicts': [
            {
              'request_id': 3,
              'title': 'Sportsfest',
              'borrow_on': '2026-09-16',
              'return_on': '2026-09-18',
              'quantity': 30,
            },
          ],
        },
        {
          'tag_id': 'CSDO-IT1-0007',
          'tracking': 'individual',
          'window_committed': 1,
          'window_free': 0,
          'available_now': 0,
          'conflicts': [],
        },
      ],
    });

    final pool = report.forTag('CSDO-FU2-0001')!;
    expect(pool.isBulk, isTrue);
    expect(pool.windowFree, 90);
    expect(pool.conflicts.single.title, 'Sportsfest');
    expect(pool.conflicts.single.rangeLabel, '2026-09-16 – 2026-09-18');

    final unit = report.forTag('CSDO-IT1-0007')!;
    expect(unit.isBulk, isFalse);
    expect(unit.windowFree, 0);
    expect(report.forTag('missing'), isNull);
  });
}
