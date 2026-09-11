import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_assisted_asset_management/main.dart';
import 'package:qr_assisted_asset_management/models/asset.dart';
import 'package:qr_assisted_asset_management/models/asset_request.dart';
import 'package:qr_assisted_asset_management/models/asset_return.dart';
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

  test('AssetRequest.isOverdue is derived from returnOn + checked-out status', () {
    AssetRequest req(RequestStatus status, DateTime returnOn) => AssetRequest(
          title: 'T',
          requester: 'Rey',
          department: 'D',
          borrowDate: 'x',
          returnDate: 'x',
          borrowOn: returnOn.subtract(const Duration(days: 2)),
          returnOn: returnOn,
          status: status,
        );

    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    final nextWeek = DateTime.now().add(const Duration(days: 7));

    // Checked out and past the return date → overdue.
    final late = req(RequestStatus.checkedOut, threeDaysAgo);
    expect(late.isOverdue, isTrue);
    expect(late.daysOverdue, 3);
    expect(late.overdueLabel, '3 days overdue');

    // Past date but only reserved (not handed out) → not overdue.
    expect(req(RequestStatus.approved, threeDaysAgo).isOverdue, isFalse);
    // Checked out but not due yet → not overdue.
    expect(req(RequestStatus.checkedOut, nextWeek).isOverdue, isFalse);
    // Already returned → never overdue.
    expect(req(RequestStatus.returned, threeDaysAgo).isOverdue, isFalse);
  });

  test('AssetItem.isLoanOverdue and AssetInspection lateness parse from JSON', () {
    final asset = AssetItem.fromJson({
      'name': 'Projector',
      'tag_id': 'CSDO-IT1-0007',
      'category_value': 'IT Equipment',
      'description': '',
      'status': 'in_use',
      'purchase_date': '2024-01-01',
      'current_holder': 'Rey',
      'due_back': 'Sep 16, 2026',
      'overdue_days': 5,
    });
    expect(asset.overdueDays, 5);
    expect(asset.isLoanOverdue, isTrue);
    expect(asset.copyWith().isLoanOverdue, isTrue);

    final onTime = AssetItem.fromJson({
      'name': 'X', 'tag_id': 'CSDO-IT1-0008', 'category_value': 'IT Equipment',
      'description': '', 'status': 'available', 'purchase_date': '2024-01-01',
    });
    expect(onTime.overdueDays, 0);
    expect(onTime.isLoanOverdue, isFalse);

    final lateReturn = AssetInspection.fromJson({
      'id': 1, 'asset_condition': 'good', 'created_at': '2026-09-20 10:00:00',
      'days_used': 6, 'days_late': 4,
    });
    expect(lateReturn.daysLate, 4);
    expect(lateReturn.wasLate, isTrue);

    final onTimeReturn = AssetInspection.fromJson({
      'id': 2, 'asset_condition': 'good', 'created_at': '2026-09-16 10:00:00',
      'days_used': 2, 'days_late': 0,
    });
    expect(onTimeReturn.wasLate, isFalse);
  });

  test('AssetRequest routing: chain gating, summary and comments from JSON', () {
    Map<String, dynamic> step(String role, int seq, String status) => {
          'role': role,
          'seq': seq,
          'status': status,
          'printed_name': 'Name $role',
        };

    AssetRequest withSteps(List<Map<String, dynamic>> steps) =>
        AssetRequest.fromJson({
          'id': 1,
          'title': 'T',
          'requester': 'R',
          'department': 'D',
          'borrow_date': 'x',
          'return_date': 'x',
          'status': 'pending',
          'approvals': steps,
          'comments': [
            {
              'id': 5,
              'author_name': 'CSDO',
              'body': 'Waiting on the dean',
              'created_at': '2026-09-15 09:00:00',
            },
          ],
        });

    // Adviser signed, principal + dean still pending → not complete.
    final partway = withSteps([
      step('adviser', 1, 'approved'),
      step('principal', 2, 'pending'),
      step('dean', 3, 'pending'),
    ]);
    expect(partway.chainComplete, isFalse);
    expect(partway.chainRejected, isFalse);
    expect(partway.nextPendingApproval?.role, ApprovalRole.principal);
    expect(partway.routingSummary, 'Awaiting Principal / Office Head');
    expect(partway.comments.single.body, 'Waiting on the dean');

    // All three approved → CSDO may approve.
    final done = withSteps([
      step('adviser', 1, 'approved'),
      step('principal', 2, 'approved'),
      step('dean', 3, 'approved'),
    ]);
    expect(done.chainComplete, isTrue);
    expect(done.routingSummary, 'Fully signed');

    // A rejected step blocks the chain and names the role.
    final rejected = withSteps([
      step('adviser', 1, 'approved'),
      step('principal', 2, 'rejected'),
      step('dean', 3, 'pending'),
    ]);
    expect(rejected.chainRejected, isTrue);
    expect(rejected.chainComplete, isFalse);
    expect(rejected.routingSummary, 'Rejected by Principal / Office Head');

    // Missing routing rows (e.g. a freshly built local request) → not complete.
    expect(withSteps(const []).chainComplete, isFalse);

    // Round-trips through toJson for the optimistic local insert.
    final body = done.toJson();
    expect((body['approvals'] as List).length, 3);
    expect((body['approvals'] as List).first['role'], 'adviser');
  });

  test('RequestStatus.withdrawn round-trips and toEditJson carries only '
      'editable fields', () {
    expect(RequestStatus.withdrawn.apiValue, 'withdrawn');
    expect(RequestStatusApiX.fromApiValue('withdrawn'), RequestStatus.withdrawn);
    expect(RequestStatus.withdrawn.label, 'Withdrawn');

    final withdrawn = AssetRequest.fromJson({
      'id': 4,
      'title': 'Cancelled fair',
      'requester': 'R',
      'department': 'D',
      'borrow_date': 'Sep 15, 2026',
      'return_date': 'Sep 16, 2026',
      'status': 'withdrawn',
      'rejection_reason': 'Event moved off campus',
    });
    expect(withdrawn.status, RequestStatus.withdrawn);
    expect(withdrawn.rejectionReason, 'Event moved off campus');

    final req = AssetRequest.fromJson({
      'id': 12,
      'title': 'ICT week seminar',
      'requester': 'Juan Dela Cruz',
      'department': 'CICS',
      'venue': 'Function Hall',
      'borrow_date': 'Sep 15, 2026',
      'return_date': 'Sep 16, 2026',
      'borrow_on': '2026-09-15',
      'return_on': '2026-09-16',
      'status': 'rejected',
      'adviser_signature': 'Prof. Ramos',
      'principal_signature': 'Engr. Ibanez',
      'dean_signature': 'Dr. Villamor',
      'logistics': [
        {'name': 'Foldable chairs', 'quantity': 120, 'category_value': 'Furniture'},
      ],
      'approvals': [
        {'role': 'adviser', 'seq': 1, 'status': 'approved', 'printed_name': 'Prof. Ramos'},
        {'role': 'principal', 'seq': 2, 'status': 'rejected', 'printed_name': 'Engr. Ibanez'},
        {'role': 'dean', 'seq': 3, 'status': 'pending', 'printed_name': 'Dr. Villamor'},
      ],
      'comments': [
        {'id': 1, 'author_name': 'CSDO', 'body': 'Fix the dates', 'created_at': '2026-09-10 09:00:00'},
      ],
    });

    final edit = req.toEditJson();
    expect(edit['action'], 'edit');
    expect(edit['id'], 12);
    expect(edit['title'], 'ICT week seminar');
    expect(edit['borrow_on'], '2026-09-15');
    expect(edit['adviser_signature'], 'Prof. Ramos');
    expect((edit['logistics'] as List).single['name'], 'Foldable chairs');
    // Status, routing decisions and the comment thread are never edited
    // through this path.
    expect(edit.containsKey('status'), isFalse);
    expect(edit.containsKey('approvals'), isFalse);
    expect(edit.containsKey('comments'), isFalse);

    // The model's fields are mutable so an optimistic in-place edit can
    // apply the saved changes without rebuilding the object.
    req.title = 'Renamed seminar';
    req.borrowOn = DateTime(2026, 10, 1);
    expect(req.title, 'Renamed seminar');
    expect(AssetRequest.isoDate(req.borrowOn), '2026-10-01');
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

  test('AssetItem.matchesSearch is a case-insensitive substring match on '
      'name or tag ID, and an empty query matches everything', () {
    final projector = AssetItem(
      name: 'Epson projector',
      tagId: 'CSDO-IT-0231',
      category: 'IT Equipment',
      description: '',
      status: AssetStatus.available,
      purchaseDate: DateTime(2024, 1, 1),
    );

    expect(projector.matchesSearch('epson'), isTrue);
    expect(projector.matchesSearch('PROJECTOR'), isTrue);
    expect(projector.matchesSearch('csdo-it-0231'), isTrue);
    expect(projector.matchesSearch('0231'), isTrue);
    expect(projector.matchesSearch('  '), isTrue);
    expect(projector.matchesSearch(''), isTrue);
    expect(projector.matchesSearch('laptop'), isFalse);

    // The exact bug this backs: a scanned/typed tag that doesn't match
    // anything exactly should still find the asset by name.
    expect(projector.matchesSearch('Epson'), isTrue);
  });

  test('AssetRequest.matchesSearch is a case-insensitive substring match on '
      'title, requester, department, or venue', () {
    final request = AssetRequest(
      title: 'ICT week seminar',
      requester: 'Juan Dela Cruz',
      department: 'CICS',
      venue: 'CICS Function Hall',
      borrowDate: 'Sep 15, 2026',
      returnDate: 'Sep 16, 2026',
    );

    expect(request.matchesSearch('ict week'), isTrue);
    expect(request.matchesSearch('juan'), isTrue);
    expect(request.matchesSearch('CICS'), isTrue);
    expect(request.matchesSearch('function hall'), isTrue);
    expect(request.matchesSearch(''), isTrue);
    expect(request.matchesSearch('gymnasium'), isFalse);

    // No venue set: matching against it must not throw.
    final noVenue = AssetRequest(
      title: 'Community outreach',
      requester: 'Pedro Reyes',
      department: 'Org',
      borrowDate: 'Jul 10, 2026',
      returnDate: 'Jul 10, 2026',
    );
    expect(noVenue.matchesSearch('pedro'), isTrue);
    expect(noVenue.matchesSearch('gymnasium'), isFalse);
  });
}
