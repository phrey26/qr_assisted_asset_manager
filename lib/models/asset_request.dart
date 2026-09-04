import 'dart:convert';
import 'dart:typed_data';

enum RequestStatus { pending, approved, rejected }

extension RequestStatusApiX on RequestStatus {
  /// The value stored in the `requests.status` column / sent to
  /// `csdo_api/requests.php`.
  String get apiValue => name;

  static RequestStatus fromApiValue(String value) {
    switch (value) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
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
      case RequestStatus.rejected:
        return 'Rejected';
    }
  }
}

/// A single logistics or equipment line on a request, with how many of it
/// are needed (e.g. "Foldable chairs" × 120).
class RequestedItem {
  const RequestedItem({required this.name, required this.quantity});

  final String name;
  final int quantity;

  /// e.g. "Foldable chairs (120)", or just "Projector" when only one is
  /// needed.
  String get label => quantity > 1 ? '$name ($quantity)' : name;

  factory RequestedItem.fromJson(Map<String, dynamic> json) => RequestedItem(
        name: json['name'] as String,
        quantity: json['quantity'] as int,
      );

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};
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
    this.status = RequestStatus.pending,
    Signatory? requesterSignature,
    Signatory? adviserSignature,
    Signatory? principalSignature,
    Signatory? deanSignature,
    this.requestFormImageBytes,
  })  : requesterSignature = requesterSignature ?? Signatory(name: requester),
        adviserSignature = adviserSignature ?? const Signatory(name: ''),
        principalSignature = principalSignature ?? const Signatory(name: ''),
        deanSignature = deanSignature ?? const Signatory(name: '');

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

  /// The first and final dates of the requested asset loan.
  final String borrowDate;
  final String returnDate;

  /// Kept as a compatibility alias for code consuming older request data.
  @Deprecated('Use borrowDate and returnDate instead.')
  String get neededDate => borrowDate;

  String get dateRangeLabel => '$borrowDate – $returnDate';

  RequestStatus status;

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
        status: RequestStatusApiX.fromApiValue(json['status'] as String? ?? 'pending'),
        requesterSignature: Signatory(name: (json['requester_signature'] as String?) ?? ''),
        adviserSignature: Signatory(name: (json['adviser_signature'] as String?) ?? ''),
        principalSignature: Signatory(name: (json['principal_signature'] as String?) ?? ''),
        deanSignature: Signatory(name: (json['dean_signature'] as String?) ?? ''),
        requestFormImageBytes: (json['request_form_image'] as String?) == null
            ? null
            : base64Decode(json['request_form_image'] as String),
      );

  /// The fields `csdo_api/requests.php` (POST) expects in its request body.
  Map<String, dynamic> toJson() => {
        'title': title,
        'requester': requester,
        'department': department,
        'venue': venue,
        'borrow_date': borrowDate,
        'return_date': returnDate,
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