import 'dart:convert';
import 'dart:math';
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
    this.unitLabel,
  });

  final String name;
  final String tagId;
  final String category;
  final String description;

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

  /// Bulk only: the unit an amount is counted in ("pcs", "box", …). Null =
  /// unlabelled (just a number).
  final String? unitLabel;

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

  /// "12 / 50 pcs" — a compact stock readout for bulk cards/rows.
  String get stockLabel {
    final unit = unitLabel == null || unitLabel!.isEmpty ? '' : ' ${unitLabel!}';
    return '$quantityAvailable / ${quantityTotal ?? 0}$unit';
  }

  /// Whether this asset was last returned in a damaged state — surfaced as
  /// a warning badge on the inventory list and asset detail, the same way
  /// [isPastLifespan] is. Never flagged for bulk items.
  bool get isDamaged => !isBulk && lastConditionRaw == 'damaged';

  /// How many years an "IT equipment" asset is expected to remain in
  /// service before it's flagged as past its lifespan.
  static const itEquipmentLifespanYears = 5;

  /// Whether this asset belongs to the IT equipment category. Matched
  /// case-insensitively since category is free text elsewhere in the app.
  bool get isItEquipment => category.toLowerCase() == 'it equipment';

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

  /// Whether this asset is IT equipment that is past its
  /// [itEquipmentLifespanYears]-year expected lifespan, based on
  /// [purchaseDate]. Non-IT-equipment assets are never flagged.
  bool get isPastLifespan {
    if (isBulk || !isItEquipment) return false;
    final limit = DateTime(
      purchaseDate.year + itEquipmentLifespanYears,
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
        unitLabel: (json['unit_label'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['unit_label'] as String).trim(),
      );

  /// The fields `csdo_api/assets.php` (POST) expects in its request body.
  Map<String, dynamic> toJson() => {
        'tag_id': tagId,
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
        'unit_label': unitLabel,
      };

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
      // Purchased more than 5 years ago, so this shows up flagged as
      // past its expected lifespan.
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

  static String nextTagId(List<AssetItem> assets) {
    final existingTags = assets.map((asset) => asset.tagId).toSet();
    const tagPrefix = 'CSDO-IT-';
    const possibleNumbers = 10000;
    final tagFormat = RegExp(r'^CSDO-IT-\d{4}$');
    final usedTagCount = existingTags.where(tagFormat.hasMatch).length;

    if (usedTagCount >= possibleNumbers) {
      throw StateError('All available CSDO-IT asset tag IDs have been used.');
    }

    final random = Random();
    while (true) {
      final number = random.nextInt(possibleNumbers).toString().padLeft(4, '0');
      final tagId = '$tagPrefix$number';
      if (!existingTags.contains(tagId)) return tagId;
    }
  }
}