import 'dart:convert';
import 'dart:typed_data';

/// The lifecycle state of an asset.
///
/// Status is driven entirely by the borrow / return / stock flows — it's
/// never hand-picked from a menu. [available] ⟷ [inUse] is the borrow and
/// return cycle; [inStock] and [maintenance] both mean the asset has been
/// moved off the active, borrowable pool (via "Move to stock", with
/// [maintenance] used when the reason was that it needs repair). Both are
/// listed on the "Stock items" screen and are put back into service with
/// "Move to active".
enum AssetStatus { available, inUse, maintenance, inStock }

/// How an asset is tracked.
///
/// [individual] — one row is one physical, QR-tagged unit with its own
/// status, timeline and return inspections (the original model).
/// [bulk] — one row is a pool of interchangeable units (cables, markers,
/// chairs…) carrying a running count. Bulk assets have no status; they're
/// borrowed/bought/disposed by quantity. A category only *suggests* which
/// mode to use — the binding flag is per asset.
enum AssetTracking { individual, bulk }

extension AssetTrackingX on AssetTracking {
  String get label => this == AssetTracking.bulk ? 'Bulk quantity' : 'Individual';

  /// Value stored in `assets.tracking` / `categories.default_tracking`.
  String get apiValue => this == AssetTracking.bulk ? 'bulk' : 'individual';

  static AssetTracking fromApiValue(String? value) =>
      value == 'bulk' ? AssetTracking.bulk : AssetTracking.individual;
}

extension AssetStatusX on AssetStatus {
  String get label {
    switch (this) {
      case AssetStatus.available:
        return 'Available';
      case AssetStatus.inUse:
        return 'In use';
      case AssetStatus.maintenance:
        return 'Maintenance';
      case AssetStatus.inStock:
        return 'In stock';
    }
  }

  /// The value stored in the `assets.status` column / sent to
  /// `csdo_api/assets.php`.
  String get apiValue {
    switch (this) {
      case AssetStatus.available:
        return 'available';
      case AssetStatus.inUse:
        return 'in_use';
      case AssetStatus.maintenance:
        return 'maintenance';
      case AssetStatus.inStock:
        return 'in_stock';
    }
  }

  /// Whether an asset in this state is a backup only and can't be borrowed.
  bool get isStock => this == AssetStatus.inStock;

  static AssetStatus fromApiValue(String value) {
    switch (value) {
      case 'in_use':
        return AssetStatus.inUse;
      case 'maintenance':
        return AssetStatus.maintenance;
      case 'in_stock':
        return AssetStatus.inStock;
      default:
        return AssetStatus.available;
    }
  }
}

class AssetItem {
  AssetItem({
    required this.name,
    required this.tagId,
    required this.category,
    required this.description,
    required this.status,
    required this.purchaseDate,
    this.imageBytes,
    this.lastConditionRaw,
    this.tracking = AssetTracking.individual,
    this.quantityTotal,
    this.quantityOut = 0,
    this.quantityDamaged = 0,
    this.reorderPoint,
    this.lifespanYears,
    this.homeLocation,
    this.custodian,
    this.lastLocation,
    this.lastScannedAt,
    this.currentHolder,
    this.currentHolderDepartment,
    this.dueBack,
  });

  final String name;
  final String tagId;
  final String category;
  final String description;

  /// Where the asset normally lives, and who's responsible for it. Free
  /// text, both optional, set on the asset's Edit form. Static "belongs to"
  /// — distinct from [currentHolder], which is whoever has it on loan now.
  final String? homeLocation;
  final String? custodian;

  /// Where an admin last physically found this asset, and when they scanned
  /// it to record that. Written by the "sighting" action from the scan
  /// result screen. [lastLocation] can be null (scanned without noting a
  /// place) even when [lastScannedAt] is set.
  final String? lastLocation;
  final DateTime? lastScannedAt;

  /// Who currently holds the asset on an approved loan, their department,
  /// and the request's return date — all derived server-side from the
  /// active request (not stored on the asset). Null when it isn't out.
  final String? currentHolder;
  final String? currentHolderDepartment;
  final String? dueBack;

  /// Expected service life in years for this asset's category, or null when
  /// the category isn't age-tracked. Resolved from the category at fetch
  /// time (`assets.php` GET joins it in as `category_lifespan_years`), so it
  /// reflects the category's current setting each time the inventory loads.
  /// Drives [isPastLifespan].
  final int? lifespanYears;

  /// Mutable so the admin can change it from the inventory page — e.g.
  /// flagging an asset as under maintenance, or bringing it back once
  /// it's fixed — without having to delete and re-add the asset.
  AssetStatus status;

  /// When the asset was purchased. Required for every asset regardless of
  /// category.
  final DateTime purchaseDate;

  /// Optional photo captured or selected when the asset was added.
  /// Keeping the bytes with the item lets the same image work on mobile,
  /// desktop, and web without relying on a temporary file path.
  final Uint8List? imageBytes;

  /// The condition slug ('good' | 'fair' | 'poor' | 'damaged') from this
  /// asset's most recent return inspection, or null if it's never been
  /// returned. Sent by `assets.php` (GET) as `last_condition`. Mutable so
  /// the requests flow can update it in place after a return, the same way
  /// [status] is kept in sync.
  String? lastConditionRaw;

  /// How this asset is tracked — individually (serialised unit) or as a
  /// bulk quantity pool. See [AssetTracking].
  final AssetTracking tracking;

  /// Bulk only: total units currently owned. Null for an individual asset.
  final int? quantityTotal;

  /// Bulk only: units currently out on loan. Mutable so the requests flow
  /// can mirror approve/return locally, the same way [status] is.
  int quantityOut;

  /// Bulk only: units back from a loan damaged and set aside pending a
  /// decision — the admin either repairs them back into available stock or
  /// disposes them for good. Not lendable while here, but still owned (they
  /// count toward [quantityTotal]). Mutable for the same local-mirror
  /// reason as [quantityOut].
  int quantityDamaged;

  /// Bulk only: low-stock threshold. When available stock falls to or below
  /// this, the asset shows a "Low stock" warning. Null = no threshold set.
  final int? reorderPoint;

  bool get isBulk => tracking == AssetTracking.bulk;

  /// Bulk only: units available to borrow right now — owned, minus what's
  /// on loan, minus what's set aside damaged.
  int get quantityAvailable => (quantityTotal ?? 0) - quantityOut - quantityDamaged;

  /// Bulk only: whether any units are currently set aside damaged.
  bool get hasDamagedStock => isBulk && quantityDamaged > 0;

  /// Bulk only: whether available stock has fallen to or below
  /// [reorderPoint].
  bool get isLowStock =>
      isBulk && reorderPoint != null && quantityAvailable <= reorderPoint!;

  /// "12 / 50" — a compact "available / owned" stock readout for bulk
  /// cards/rows.
  String get stockLabel => '$quantityAvailable / ${quantityTotal ?? 0}';

  /// Whether this asset was last returned in a damaged state — surfaced as
  /// a warning badge on the inventory list and asset detail, the same way
  /// [isPastLifespan] is. Never flagged for bulk items.
  bool get isDamaged => !isBulk && lastConditionRaw == 'damaged';

  /// Whether this asset is a backup ("stock") item — kept off the main
  /// inventory and not available to be borrowed until it's activated.
  bool get isInStock => status.isStock;

  /// Whether this asset is part of the active, borrowable inventory —
  /// either [AssetStatus.available] or currently [AssetStatus.inUse].
  /// Everything else ([AssetStatus.inStock] and [AssetStatus.maintenance])
  /// has been filed out onto the "Stock items" screen. Bulk pools are
  /// always active — they carry a level, not a status.
  bool get isActiveInventory =>
      isBulk ||
      status == AssetStatus.available ||
      status == AssetStatus.inUse;

  /// Whether this asset is past the expected lifespan set on its category,
  /// based on [purchaseDate]. Assets whose category isn't age-tracked
  /// ([lifespanYears] is null) and bulk pools are never flagged.
  bool get isPastLifespan {
    final years = lifespanYears;
    if (isBulk || years == null || years <= 0) return false;
    final limit = DateTime(
      purchaseDate.year + years,
      purchaseDate.month,
      purchaseDate.day,
    );
    return DateTime.now().isAfter(limit);
  }

  /// Builds an [AssetItem] from an `assets` row returned by
  /// `csdo_api/assets.php` (GET) — `category` is filled in from the joined
  /// `category_value` field so it matches an [AssetCategory.value] exactly.
  factory AssetItem.fromJson(Map<String, dynamic> json) => AssetItem(
        name: json['name'] as String,
        tagId: json['tag_id'] as String,
        category: json['category_value'] as String,
        description: (json['description'] as String?) ?? '',
        status: AssetStatusX.fromApiValue(json['status'] as String? ?? 'available'),
        purchaseDate: DateTime.parse(json['purchase_date'] as String),
        imageBytes: (json['image_base64'] as String?) == null
            ? null
            : base64Decode(json['image_base64'] as String),
        lastConditionRaw: (json['last_condition'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['last_condition'] as String,
        tracking: AssetTrackingX.fromApiValue(json['tracking'] as String?),
        quantityTotal: (json['quantity_total'] as num?)?.toInt(),
        quantityOut: (json['quantity_out'] as num?)?.toInt() ?? 0,
        quantityDamaged: (json['quantity_damaged'] as num?)?.toInt() ?? 0,
        reorderPoint: (json['reorder_point'] as num?)?.toInt(),
        lifespanYears: (json['category_lifespan_years'] as num?)?.toInt(),
        homeLocation: _str(json['home_location']),
        custodian: _str(json['custodian']),
        lastLocation: _str(json['last_location']),
        lastScannedAt: DateTime.tryParse(
          (json['last_scanned_at'] as String?) ?? '',
        )?.toLocal(),
        currentHolder: _str(json['current_holder']),
        currentHolderDepartment: _str(json['current_holder_department']),
        dueBack: _str(json['due_back']),
      );

  /// Trims a JSON string, returning null for null/blank.
  static String? _str(Object? value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// The fields `csdo_api/assets.php` (POST) expects in its request body.
  /// No `tag_id` — it's allocated by the backend on insert and handed back
  /// in the response (see [ApiService.addAsset]).
  Map<String, dynamic> toJson() => {
        'name': name,
        'category_id': null, // filled in by the caller, which knows the id
        'description': description,
        'status': status.apiValue,
        'purchase_date':
            '${purchaseDate.year.toString().padLeft(4, '0')}-'
            '${purchaseDate.month.toString().padLeft(2, '0')}-'
            '${purchaseDate.day.toString().padLeft(2, '0')}',
        'image_base64': imageBytes == null ? null : base64Encode(imageBytes!),
        'tracking': tracking.apiValue,
        'quantity_total': quantityTotal,
        'reorder_point': reorderPoint,
        'home_location': homeLocation,
        'custodian': custodian,
      };

  /// The body for `csdo_api/assets.php` PUT with `action: 'edit'`. Only the
  /// admin-editable fields — never `tag_id` (identity), `tracking` or
  /// `status`. `category_id` is filled in by the caller, which knows the id.
  /// `reorder_point` is only meaningful for bulk assets.
  Map<String, dynamic> editJson() => {
        'action': 'edit',
        'tag_id': tagId,
        'name': name,
        'category_id': null,
        'description': description,
        'purchase_date':
            '${purchaseDate.year.toString().padLeft(4, '0')}-'
            '${purchaseDate.month.toString().padLeft(2, '0')}-'
            '${purchaseDate.day.toString().padLeft(2, '0')}',
        'image_base64': imageBytes == null ? null : base64Encode(imageBytes!),
        'home_location': homeLocation,
        'custodian': custodian,
        if (isBulk) 'reorder_point': reorderPoint,
      };

  /// "Sep 10, 2025 · 2:45 PM" for [lastScannedAt], or null if never scanned.
  String? get formattedLastScannedAt {
    final at = lastScannedAt;
    if (at == null) return null;
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    final ap = at.hour < 12 ? 'AM' : 'PM';
    return '${formatDate(at)} · $h:$m $ap';
  }

  static List<AssetItem> samples = [
    AssetItem(
      name: 'Epson projector',
      tagId: 'CSDO-IT-0231',
      category: 'IT equipment',
      description: 'Portable projector for classroom presentations.',
      status: AssetStatus.available,
      purchaseDate: DateTime(2024, 6, 12),
    ),
    AssetItem(
      name: 'Dell Latitude 5420',
      tagId: 'CSDO-IT-0198',
      category: 'IT equipment',
      description: 'Assigned office laptop.',
      status: AssetStatus.inUse,
      purchaseDate: DateTime(2023, 11, 3),
    ),
    AssetItem(
      name: 'HP LaserJet Pro M404',
      tagId: 'CSDO-IT-0104',
      category: 'IT equipment',
      description: 'Shared office printer.',
      status: AssetStatus.available,
      // Purchased long ago: flagged as past its lifespan once its category
      // ("IT Equipment") carries a lifespan_years (5 for the built-in).
      purchaseDate: DateTime(2019, 4, 18),
    ),
    AssetItem(
      name: 'Steel folding chair',
      tagId: 'CSDO-FN-0871',
      category: 'Furniture',
      description: 'Foldable steel chair.',
      status: AssetStatus.available,
      purchaseDate: DateTime(2022, 8, 20),
    ),
    AssetItem(
      name: 'Split-type aircon',
      tagId: 'CSDO-MT-0042',
      category: 'Tools',
      description: 'Wall-mounted split type air-conditioning unit.',
      status: AssetStatus.maintenance,
      purchaseDate: DateTime(2021, 3, 15),
    ),
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats [purchaseDate] as e.g. "Jun 12, 2024" without pulling in the
  /// intl package for a single label.
  String get formattedPurchaseDate => formatDate(purchaseDate);

  /// Formats any [DateTime] as e.g. "Jun 12, 2024". Static so callers (like
  /// the add-asset form) can preview a date before an AssetItem exists.
  static String formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  /// Best-effort inverse of [formatDate]: parses "Jun 12, 2024" (and a
  /// plain ISO "2024-06-12") back to a [DateTime], or null if it can't.
  /// Used to estimate how many days an asset was out on loan from the
  /// request's stored date strings.
  static DateTime? tryParseDate(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final match = RegExp(r'^([A-Za-z]{3})[a-z]*\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(text);
    if (match == null) return null;
    final month = _months.indexWhere(
      (m) => m.toLowerCase() == match.group(1)!.toLowerCase(),
    );
    if (month < 0) return null;
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || year == null) return null;
    return DateTime(year, month + 1, day);
  }

  /// A copy of this asset with the given fields replaced. Used to stamp the
  /// backend-allocated [tagId] onto the asset once `csdo_api/assets.php`
  /// (POST) returns it — the form builds the asset with an empty tag.
  AssetItem copyWith({
    String? name,
    String? tagId,
    String? category,
    String? description,
    AssetStatus? status,
    DateTime? purchaseDate,
    Uint8List? imageBytes,
    String? lastConditionRaw,
    AssetTracking? tracking,
    int? quantityTotal,
    int? quantityOut,
    int? quantityDamaged,
    int? reorderPoint,
    int? lifespanYears,
    String? homeLocation,
    String? custodian,
    String? lastLocation,
    DateTime? lastScannedAt,
    String? currentHolder,
    String? currentHolderDepartment,
    String? dueBack,
  }) =>
      AssetItem(
        name: name ?? this.name,
        tagId: tagId ?? this.tagId,
        category: category ?? this.category,
        description: description ?? this.description,
        status: status ?? this.status,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        imageBytes: imageBytes ?? this.imageBytes,
        lastConditionRaw: lastConditionRaw ?? this.lastConditionRaw,
        tracking: tracking ?? this.tracking,
        quantityTotal: quantityTotal ?? this.quantityTotal,
        quantityOut: quantityOut ?? this.quantityOut,
        quantityDamaged: quantityDamaged ?? this.quantityDamaged,
        reorderPoint: reorderPoint ?? this.reorderPoint,
        lifespanYears: lifespanYears ?? this.lifespanYears,
        homeLocation: homeLocation ?? this.homeLocation,
        custodian: custodian ?? this.custodian,
        lastLocation: lastLocation ?? this.lastLocation,
        lastScannedAt: lastScannedAt ?? this.lastScannedAt,
        currentHolder: currentHolder ?? this.currentHolder,
        currentHolderDepartment:
            currentHolderDepartment ?? this.currentHolderDepartment,
        dueBack: dueBack ?? this.dueBack,
      );
}