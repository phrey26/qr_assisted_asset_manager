import 'dart:typed_data';

enum RequestStatus { pending, approved, rejected }

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

/// One signature block on the borrow slip: the printed name plus the
/// scanned image of that person's actual signature (uploaded from the
/// device gallery or camera in lieu of a wet-ink signature on paper).
class Signatory {
  const Signatory({required this.name, this.imageBytes});

  final String name;

  /// Bytes of the uploaded/scanned signature image, or null if this
  /// person hasn't signed yet.
  final Uint8List? imageBytes;

  bool get hasSigned => imageBytes != null;

  Signatory copyWith({String? name, Uint8List? imageBytes}) => Signatory(
        name: name ?? this.name,
        imageBytes: imageBytes ?? this.imageBytes,
      );
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
}

/// A request from a requester/department to borrow a venue/facility,
/// logistics, and/or equipment for an event — mirrors the office's actual
/// borrow slip: event/purpose, requester, department, venue, logistics
/// (with amounts), equipment (with amounts), and the period of the loan.
class AssetRequest {
  AssetRequest({
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
  })  : requesterSignature = requesterSignature ?? Signatory(name: requester),
        adviserSignature = adviserSignature ?? const Signatory(name: ''),
        principalSignature = principalSignature ?? const Signatory(name: ''),
        deanSignature = deanSignature ?? const Signatory(name: '');

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

  /// All four signature blocks, in the order they appear on the paper
  /// slip: requester, adviser, principal/office head, dean.
  List<MapEntry<SignatoryRole, Signatory>> get signatories => [
        MapEntry(SignatoryRole.requester, requesterSignature),
        MapEntry(SignatoryRole.adviser, adviserSignature),
        MapEntry(SignatoryRole.principal, principalSignature),
        MapEntry(SignatoryRole.dean, deanSignature),
      ];

  /// How many of the four required signatures have actually been signed.
  int get signedCount => signatories.where((e) => e.value.hasSigned).length;

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
      // Shows what a fully-signed slip looks like; the actual signature
      // images are left blank since samples ship without real scans, but
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
