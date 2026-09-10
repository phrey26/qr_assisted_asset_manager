// Models for `csdo_api/availability.php` — how much of each asset is free
// for a specific loan window, so the approval picker and the new-request
// form can show real "N free for these dates" figures instead of a
// point-in-time "is it out right now" guess.

/// One approved request that already has a claim on an asset for a window
/// overlapping the one being checked — surfaced so the picker (and the
/// approval error message) can name what the clash is with.
class WindowConflict {
  const WindowConflict({
    required this.requestId,
    required this.title,
    required this.borrowOn,
    required this.returnOn,
    required this.quantity,
  });

  final int requestId;
  final String title;
  final String borrowOn;
  final String returnOn;
  final int quantity;

  /// "2026-09-15" for a same-day loan, "2026-09-15 – 2026-09-16" otherwise.
  String get rangeLabel {
    if (borrowOn.isEmpty && returnOn.isEmpty) return '';
    if (borrowOn == returnOn || returnOn.isEmpty) return borrowOn;
    if (borrowOn.isEmpty) return returnOn;
    return '$borrowOn – $returnOn';
  }

  factory WindowConflict.fromJson(Map<String, dynamic> json) => WindowConflict(
        requestId: (json['request_id'] as num?)?.toInt() ?? 0,
        title: (json['title'] as String?) ?? 'Request',
        borrowOn: (json['borrow_on'] as String?) ?? '',
        returnOn: (json['return_on'] as String?) ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

/// How much of one asset is free for a specific loan window.
///
/// [windowFree] is in units — 0 or 1 for an individual asset, 0..owned for a
/// bulk pool. [availableNow] is the point-in-time figure the current borrow
/// flow uses, kept so the picker can stay at least as strict as it was.
class AssetWindowAvailability {
  const AssetWindowAvailability({
    required this.tagId,
    required this.isBulk,
    required this.windowCommitted,
    required this.windowFree,
    required this.availableNow,
    this.conflicts = const [],
  });

  final String tagId;
  final bool isBulk;

  /// Units already committed to other approved requests overlapping the
  /// window.
  final int windowCommitted;

  /// Units free to lend for the whole window.
  final int windowFree;

  /// Units free right now (owned − out − damaged for a pool; 1 iff
  /// `available` for an individual asset).
  final int availableNow;

  final List<WindowConflict> conflicts;

  factory AssetWindowAvailability.fromJson(Map<String, dynamic> json) =>
      AssetWindowAvailability(
        tagId: json['tag_id'] as String,
        isBulk: (json['tracking'] as String?) == 'bulk',
        windowCommitted: (json['window_committed'] as num?)?.toInt() ?? 0,
        windowFree: (json['window_free'] as num?)?.toInt() ?? 0,
        availableNow: (json['available_now'] as num?)?.toInt() ?? 0,
        conflicts: (json['conflicts'] as List<dynamic>? ?? [])
            .map((c) => WindowConflict.fromJson((c as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// The full `availability.php` response: the resolved window plus a lookup
/// of tag ID → availability for it.
class WindowAvailabilityReport {
  const WindowAvailabilityReport({
    required this.from,
    required this.to,
    required this.byTagId,
  });

  final String from;
  final String to;
  final Map<String, AssetWindowAvailability> byTagId;

  AssetWindowAvailability? forTag(String tagId) => byTagId[tagId];

  factory WindowAvailabilityReport.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List<dynamic>? ?? [])
        .map((a) =>
            AssetWindowAvailability.fromJson((a as Map).cast<String, dynamic>()))
        .toList();
    return WindowAvailabilityReport(
      from: (json['from'] as String?) ?? '',
      to: (json['to'] as String?) ?? '',
      byTagId: {for (final a in assets) a.tagId: a},
    );
  }
}
