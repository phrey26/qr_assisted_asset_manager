enum RequestStatus { pending, approved, rejected }

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

/// A request from a requester/department to borrow or use an asset.
class AssetRequest {
  AssetRequest({
    required this.title,
    required this.requester,
    required this.department,
    required this.itemDescription,
    this.neededDate,
    this.status = RequestStatus.pending,
  });

  final String title;
  final String requester;
  final String department;
  final String itemDescription;
  final String? neededDate;
  RequestStatus status;

  String get detailLine {
    final parts = [
      requester,
      department,
      itemDescription,
      if (neededDate != null) 'Needed $neededDate',
    ];
    return parts.join(' · ');
  }

  static List<AssetRequest> samples = [
    AssetRequest(
      title: 'Freshmen orientation',
      requester: 'Maria Santos',
      department: 'OSA',
      itemDescription: 'Wireless microphone',
      neededDate: 'Aug 29, 2026',
      status: RequestStatus.pending,
    ),
    AssetRequest(
      title: 'ICT week seminar',
      requester: 'Juan Dela Cruz',
      department: 'CICS',
      itemDescription: 'Foldable chairs (120)',
      status: RequestStatus.approved,
    ),
    AssetRequest(
      title: 'Community outreach',
      requester: 'Pedro Reyes',
      department: 'Org',
      itemDescription: 'Service vehicle (van)',
      status: RequestStatus.rejected,
    ),
  ];
}
