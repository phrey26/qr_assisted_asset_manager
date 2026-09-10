import 'dart:convert';
import 'dart:typed_data';

import 'asset.dart';

/// The lifecycle of a borrow request.
///
/// [approved] only *reserves* the picked assets for the loan window —
/// nothing physical has moved. [checkedOut] is when those reserved assets
/// are actually handed over (individual units become `in_use`, bulk stock
/// is decremented). [returned] is terminal: the borrowed assets came back
/// and were freed, but the request keeps its record of what was lent.
/// [rejected] is terminal too.
enum RequestStatus { pending, approved, checkedOut, rejected, returned }

extension RequestStatusApiX on RequestStatus {
  /// The value stored in the `requests.status` column / sent to
  /// `csdo_api/requests.php`.
  String get apiValue =>
      this == RequestStatus.checkedOut ? 'checked_out' : name;

  static RequestStatus fromApiValue(String value) {
    switch (value) {
      case 'approved':
        return RequestStatus.approved;
      case 'checked_out':
        return RequestStatus.checkedOut;
      case 'rejected':
        return RequestStatus.rejected;
      case 'returned':
        return RequestStatus.returned;
      default:
        return RequestStatus.pending;
    }
  }
}

/// The four roles the paper borrow slip always collects a
/// signature-over-printed-name for, in the order they appear on that slip.
enum SignatoryRole { requester, adviser, principal, dean }

extension SignatoryRoleX on SignatoryRole {
  String get label {
    switch (this) {
      case SignatoryRole.requester:
        return 'Requester';
      case SignatoryRole.adviser:
        return 'Adviser';
      case SignatoryRole.principal:
        return 'Principal / Office Head';
      case SignatoryRole.dean:
        return 'Dean';
    }
  }
}

/// One signature block on the borrow slip: just the printed name for that
/// role. The actual signature is no longer captured per-person — it's
/// covered by the single photo of the whole signed CSDO Request Form
/// (see [AssetRequest.requestFormImageBytes]).
class Signatory {
  const Signatory({required this.name});

  final String name;

  Signatory copyWith({String? name}) => Signatory(name: name ?? this.name);
}

extension RequestStatusX on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.checkedOut:
        return 'Checked out';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.returned:
        return 'Returned';
    }
  }
}

/// One real asset from the inventory that's been handed out to fulfil an
/// approved request. Built from the `assets` array on a `requests` row
/// returned by `csdo_api/requests.php` (GET), or straight from an
/// [AssetItem] the admin just picked in the approval flow. Display-only —
/// the assignment itself lives in the backend `request_assets` table and
/// is keyed by [tagId].
class AssignedAsset {
  const AssignedAsset({
    required this.tagId,
    required this.name,
    required this.category,
    required this.status,
    this.tracking = AssetTracking.individual,
    this.quantity = 1,
  });

  final String tagId;
  final String name;
  final String category;

  /// The asset's status as of the last load. While an individual asset is
  /// assigned to an approved request this is [AssetStatus.inUse]. Not
  /// meaningful for a bulk line (a pool has no status).
  final AssetStatus status;

  /// How the underlying asset is tracked. A bulk line represents [quantity]
  /// units taken from a pool rather than one physical unit.
  final AssetTracking tracking;

  /// Units taken. Always 1 for an individual asset; N for a bulk line.
  final int quantity;

  bool get isBulk => tracking == AssetTracking.bulk;

  /// "Foldable chairs ×120" for a bulk line, just the name otherwise.
  String get displayLabel => isBulk && quantity > 1 ? '$name ×$quantity' : name;

  factory AssignedAsset.fromJson(Map<String, dynamic> json) => AssignedAsset(
        tagId: json['tag_id'] as String,
        name: (json['name'] as String?) ?? (json['tag_id'] as String),
        category: (json['category_value'] as String?) ?? '',
        status: AssetStatusX.fromApiValue(json['status'] as String? ?? 'in_use'),
        tracking: AssetTrackingX.fromApiValue(json['tracking'] as String?),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  factory AssignedAsset.fromAsset(AssetItem asset, {int quantity = 1}) => AssignedAsset(
        tagId: asset.tagId,
        name: asset.name,
        category: asset.category,
        status: asset.isBulk ? AssetStatus.available : AssetStatus.inUse,
        tracking: asset.tracking,
        quantity: asset.isBulk ? quantity : 1,
      );
}

/// A single logistics or equipment line on a request, with how many of it
/// are needed (e.g. "Foldable chairs" × 120).
class RequestedItem {
  const RequestedItem({
    required this.name,
    required this.quantity,
    this.categoryId,
    this.categoryValue,
  });

  final String name;
  final int quantity;

  /// Optional soft link to the inventory category this line is asking for
  /// (its `categories.id` and matching [AssetCategory.value]). Set when the
  /// requester picked a category on the new-request form; null when the line
  /// was left as free text. Lets the approval picker scope its suggestions
  /// to the right pool instead of guessing from [name].
  final int? categoryId;
  final String? categoryValue;

  bool get isLinked => categoryId != null;

  /// e.g. "Foldable chairs (120)", or just "Projector" when only one is
  /// needed.
  String get label => quantity > 1 ? '$name ($quantity)' : name;

  factory RequestedItem.fromJson(Map<String, dynamic> json) => RequestedItem(
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toInt(),
        categoryId: (json['category_id'] as num?)?.toInt(),
        categoryValue: (json['category_value'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['category_value'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        // `category_id` is what the backend stores; `category_value` is
        // ignored there but kept so a locally round-tripped request (built
        // straight from its own toJson right after create) keeps the label.
        if (categoryId != null) 'category_id': categoryId,
        if (categoryValue != null) 'category_value': categoryValue,
      };
}

/// A request from a requester/department to borrow a venue/facility,
/// logistics, and/or equipment for an event — mirrors the office's actual
/// borrow slip: event/purpose, requester, department, venue, logistics
/// (with amounts), equipment (with amounts), and the period of the loan.
class AssetRequest {
  AssetRequest({
    this.id,
    required this.title,
    required this.requester,
    required this.department,
    this.venue,
    this.logistics = const [],
    this.equipment = const [],
    required this.borrowDate,
    required this.returnDate,
    this.borrowOn,
    this.returnOn,
    this.status = RequestStatus.pending,
    Signatory? requesterSignature,
    Signatory? adviserSignature,
    Signatory? principalSignature,
    Signatory? deanSignature,
    this.requestFormImageBytes,
    List<AssignedAsset>? assignedAssets,
  })  : requesterSignature = requesterSignature ?? Signatory(name: requester),
        adviserSignature = adviserSignature ?? const Signatory(name: ''),
        principalSignature = principalSignature ?? const Signatory(name: ''),
        deanSignature = deanSignature ?? const Signatory(name: ''),
        assignedAssets = assignedAssets ?? const [];

  /// The `requests.id` primary key once this request has been saved via the
  /// API. Null for a request built locally that hasn't been submitted yet.
  final int? id;

  final String title;
  final String requester;
  final String department;

  /// The venue/facility being requested (e.g. "Gymnasium"). Null when the
  /// request is for logistics/equipment only and doesn't need a venue.
  final String? venue;

  /// Logistics items requested, each with the amount needed.
  final List<RequestedItem> logistics;

  /// Equipment items requested, each with the amount needed.
  final List<RequestedItem> equipment;

  /// The first and final dates of the requested asset loan, as the app
  /// formats them for display (e.g. "Sep 15, 2026").
  final String borrowDate;
  final String returnDate;

  /// The same loan window as machine-comparable dates (from the backend's
  /// `borrow_on` / `return_on` columns). Used for the availability /
  /// double-booking checks. Null only for legacy rows whose display strings
  /// couldn't be parsed server-side.
  final DateTime? borrowOn;
  final DateTime? returnOn;

  /// Kept as a compatibility alias for code consuming older request data.
  @Deprecated('Use borrowDate and returnDate instead.')
  String get neededDate => borrowDate;

  String get dateRangeLabel => '$borrowDate – $returnDate';

  RequestStatus status;

  /// Whole days this loan is past its return date — 0 unless the request is
  /// [RequestStatus.checkedOut] (physically out) and [returnOn] is before
  /// today. Derived, so it stays correct after a local status change without
  /// a reload.
  int get daysOverdue {
    if (status != RequestStatus.checkedOut || returnOn == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(returnOn!.year, returnOn!.month, returnOn!.day);
    final diff = today.difference(due).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Whether this loan is overdue — checked out and past [returnOn].
  bool get isOverdue => daysOverdue > 0;

  /// "4 days overdue" / "1 day overdue".
  String get overdueLabel =>
      '$daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue';

  /// The requester's own signature — normally filled in on submission,
  /// signing over their printed name.
  Signatory requesterSignature;

  /// The requester's class/org adviser's signature.
  Signatory adviserSignature;

  /// The principal's (or, for non-academic requests, the office head's)
  /// signature.
  Signatory principalSignature;

  /// The dean's signature — the final approval on the paper slip.
  Signatory deanSignature;

  /// A single scanned/photographed image of the filled-out, physically
  /// signed CSDO Request Form — the printed names above are typed in for
  /// reference, but all four wet-ink signatures live on this one photo.
  Uint8List? requestFormImageBytes;

  /// The real inventory assets handed out for this request. Non-empty only
  /// while the request is approved — the admin picks these in the approval
  /// flow, and they're released (back to this list being empty) when the
  /// approval is cancelled or the request is rejected. Mutable so those
  /// flows can update it in place, mirroring [status].
  List<AssignedAsset> assignedAssets;

  /// Whether the CSDO Request Form photo has been attached.
  bool get hasRequestForm => requestFormImageBytes != null;

  /// All four signature blocks, in the order they appear on the paper
  /// slip: requester, adviser, principal/office head, dean.
  List<MapEntry<SignatoryRole, Signatory>> get signatories => [
        MapEntry(SignatoryRole.requester, requesterSignature),
        MapEntry(SignatoryRole.adviser, adviserSignature),
        MapEntry(SignatoryRole.principal, principalSignature),
        MapEntry(SignatoryRole.dean, deanSignature),
      ];

  /// Every logistics + equipment line combined, in that order.
  List<RequestedItem> get allItems => [...logistics, ...equipment];

  /// A short, comma-joined summary of everything requested — the venue (if
  /// any) followed by each item and its amount — for compact display in
  /// list/table rows. e.g. "Gymnasium, Foldable chairs (120), Projector".
  String get itemsSummary {
    final parts = [
      if (venue != null && venue!.isNotEmpty) venue!,
      ...allItems.map((item) => item.label),
    ];
    return parts.isEmpty ? 'No items specified' : parts.join(', ');
  }

  String get detailLine {
    final parts = [requester, department, itemsSummary, 'Borrow $dateRangeLabel'];
    return parts.join(' · ');
  }

  /// Parses a backend `borrow_on` / `return_on` value ('YYYY-MM-DD', or
  /// null) to a local [DateTime], or null when absent/unparseable.
  static DateTime? _parseIsoDate(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  /// Formats a [DateTime] as the `YYYY-MM-DD` string the backend's
  /// `borrow_on` / `return_on` columns (and `availability.php`) expect.
  static String? isoDate(DateTime? date) => date == null
      ? null
      : '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  /// Builds an [AssetRequest] from a `requests` row (with nested
  /// `logistics`/`equipment` arrays) returned by `csdo_api/requests.php`
  /// (GET).
  factory AssetRequest.fromJson(Map<String, dynamic> json) => AssetRequest(
        id: json['id'] as int,
        title: json['title'] as String,
        requester: json['requester'] as String,
        department: json['department'] as String,
        venue: json['venue'] as String?,
        logistics: (json['logistics'] as List<dynamic>? ?? [])
            .map((item) => RequestedItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        equipment: (json['equipment'] as List<dynamic>? ?? [])
            .map((item) => RequestedItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        borrowDate: json['borrow_date'] as String,
        returnDate: json['return_date'] as String,
        borrowOn: _parseIsoDate(json['borrow_on']),
        returnOn: _parseIsoDate(json['return_on']),
        status: RequestStatusApiX.fromApiValue(json['status'] as String? ?? 'pending'),
        requesterSignature: Signatory(name: (json['requester_signature'] as String?) ?? ''),
        adviserSignature: Signatory(name: (json['adviser_signature'] as String?) ?? ''),
        principalSignature: Signatory(name: (json['principal_signature'] as String?) ?? ''),
        deanSignature: Signatory(name: (json['dean_signature'] as String?) ?? ''),
        requestFormImageBytes: (json['request_form_image'] as String?) == null
            ? null
            : base64Decode(json['request_form_image'] as String),
        assignedAssets: (json['assets'] as List<dynamic>? ?? [])
            .map((item) => AssignedAsset.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  /// The fields `csdo_api/requests.php` (POST) expects in its request body.
  Map<String, dynamic> toJson() => {
        'title': title,
        'requester': requester,
        'department': department,
        'venue': venue,
        'borrow_date': borrowDate,
        'return_date': returnDate,
        'borrow_on': isoDate(borrowOn),
        'return_on': isoDate(returnOn),
        'status': status.apiValue,
        'requester_signature': requesterSignature.name,
        'adviser_signature': adviserSignature.name,
        'principal_signature': principalSignature.name,
        'dean_signature': deanSignature.name,
        'request_form_image':
            requestFormImageBytes == null ? null : base64Encode(requestFormImageBytes!),
        'logistics': logistics.map((item) => item.toJson()).toList(),
        'equipment': equipment.map((item) => item.toJson()).toList(),
      };

  static List<AssetRequest> samples = [
    AssetRequest(
      title: 'Freshmen orientation',
      requester: 'Maria Santos',
      department: 'OSA',
      venue: 'Gymnasium',
      equipment: const [RequestedItem(name: 'Wireless microphone', quantity: 2)],
      borrowDate: 'Aug 29, 2026',
      returnDate: 'Aug 29, 2026',
      status: RequestStatus.pending,
    ),
    AssetRequest(
      title: 'ICT week seminar',
      requester: 'Juan Dela Cruz',
      department: 'CICS',
      venue: 'CICS Function Hall',
      logistics: const [RequestedItem(name: 'Foldable chairs', quantity: 120)],
      equipment: const [RequestedItem(name: 'Projector', quantity: 1)],
      borrowDate: 'Sep 15, 2026',
      returnDate: 'Sep 16, 2026',
      status: RequestStatus.approved,
      // Shows what a filled-out slip looks like; the CSDO Request Form
      // photo is left blank since samples ship without a real scan, but
      // the printed names alone still demonstrate the four-signatory flow.
      adviserSignature: const Signatory(name: 'Prof. Liza Ramos'),
      principalSignature: const Signatory(name: 'Engr. Noel Ibañez'),
      deanSignature: const Signatory(name: 'Dr. Corazon Villamor'),
    ),
    AssetRequest(
      title: 'Community outreach',
      requester: 'Pedro Reyes',
      department: 'Org',
      equipment: const [RequestedItem(name: 'Service vehicle (van)', quantity: 1)],
      borrowDate: 'Jul 10, 2026',
      returnDate: 'Jul 10, 2026',
      status: RequestStatus.rejected,
    ),
  ];
}