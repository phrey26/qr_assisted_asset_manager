/// One (week, label, count) triple from a weekly-bucketed report —
/// `requests_by_week` (label = request status) or `stock_movement_summary`
/// (label = 'in'/'out'). See `csdo_api/reports.php`.
class WeekCount {
  const WeekCount({required this.weekStart, required this.label, required this.count});

  final DateTime weekStart;
  final String label;
  final int count;

  factory WeekCount.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    required String countKey,
  }) {
    return WeekCount(
      weekStart: DateTime.parse(json['week_start'] as String),
      label: json[labelKey] as String,
      count: (json[countKey] as num).toInt(),
    );
  }
}

/// A simple name -> count pair — `status_breakdown` (name = asset status)
/// or `department_demand` (name = department).
class NamedCount {
  const NamedCount({required this.name, required this.count});

  final String name;
  final int count;

  factory NamedCount.fromJson(
    Map<String, dynamic> json, {
    required String nameKey,
    required String countKey,
  }) {
    return NamedCount(name: json[nameKey] as String, count: (json[countKey] as num).toInt());
  }
}

/// One row of `top_assets` — how many times an asset has been borrowed,
/// combining individual-asset 'borrowed' events and bulk-asset 'lent' stock
/// movements (summed server-side; see reports.php).
class TopBorrowedAsset {
  const TopBorrowedAsset({
    required this.tagId,
    required this.name,
    required this.category,
    required this.timesBorrowed,
  });

  final String tagId;
  final String name;
  final String? category;
  final int timesBorrowed;

  factory TopBorrowedAsset.fromJson(Map<String, dynamic> json) {
    return TopBorrowedAsset(
      tagId: json['tag_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      timesBorrowed: (json['times_borrowed'] as num).toInt(),
    );
  }
}

/// The full `reports.php` payload — everything the dashboard's charts need,
/// fetched in a single round trip. See `ApiService.fetchReports`.
class ReportsBundle {
  const ReportsBundle({
    required this.requestsByWeek,
    required this.statusBreakdown,
    required this.topAssets,
    required this.departmentDemand,
    required this.stockMovementSummary,
  });

  final List<WeekCount> requestsByWeek;
  final List<NamedCount> statusBreakdown;
  final List<TopBorrowedAsset> topAssets;
  final List<NamedCount> departmentDemand;
  final List<WeekCount> stockMovementSummary;

  factory ReportsBundle.fromJson(Map<String, dynamic> json) {
    final requestsByWeek = ((json['requests_by_week'] as List<dynamic>?) ?? const [])
        .map(
          (e) => WeekCount.fromJson(
            e as Map<String, dynamic>,
            labelKey: 'status',
            countKey: 'count',
          ),
        )
        .toList();
    final statusBreakdown = ((json['status_breakdown'] as List<dynamic>?) ?? const [])
        .map(
          (e) => NamedCount.fromJson(
            e as Map<String, dynamic>,
            nameKey: 'status',
            countKey: 'count',
          ),
        )
        .toList();
    final topAssets = ((json['top_assets'] as List<dynamic>?) ?? const [])
        .map((e) => TopBorrowedAsset.fromJson(e as Map<String, dynamic>))
        .toList();
    final departmentDemand = ((json['department_demand'] as List<dynamic>?) ?? const [])
        .map(
          (e) => NamedCount.fromJson(
            e as Map<String, dynamic>,
            nameKey: 'department',
            countKey: 'count',
          ),
        )
        .toList();
    final stockMovementSummary = ((json['stock_movement_summary'] as List<dynamic>?) ?? const [])
        .map(
          (e) => WeekCount.fromJson(
            e as Map<String, dynamic>,
            labelKey: 'direction',
            countKey: 'units',
          ),
        )
        .toList();
    return ReportsBundle(
      requestsByWeek: requestsByWeek,
      statusBreakdown: statusBreakdown,
      topAssets: topAssets,
      departmentDemand: departmentDemand,
      stockMovementSummary: stockMovementSummary,
    );
  }

  /// True when every section came back empty — a fresh install with no
  /// history yet, or (for the two weekly trends) simply nothing in the
  /// lookback window. Drives the reports section's empty state.
  bool get isEmpty =>
      requestsByWeek.isEmpty &&
      statusBreakdown.isEmpty &&
      topAssets.isEmpty &&
      departmentDemand.isEmpty &&
      stockMovementSummary.isEmpty;
}
