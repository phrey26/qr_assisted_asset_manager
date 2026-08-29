import 'dart:math';
import 'dart:typed_data';

enum AssetStatus { available, inUse, maintenance }

extension AssetStatusX on AssetStatus {
  String get label {
    switch (this) {
      case AssetStatus.available:
        return 'Available';
      case AssetStatus.inUse:
        return 'In use';
      case AssetStatus.maintenance:
        return 'Maintenance';
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

  /// How many years an "IT equipment" asset is expected to remain in
  /// service before it's flagged as past its lifespan.
  static const itEquipmentLifespanYears = 5;

  /// Whether this asset belongs to the IT equipment category. Matched
  /// case-insensitively since category is free text elsewhere in the app.
  bool get isItEquipment => category.toLowerCase() == 'it equipment';

  /// Whether this asset is IT equipment that is past its
  /// [itEquipmentLifespanYears]-year expected lifespan, based on
  /// [purchaseDate]. Non-IT-equipment assets are never flagged.
  bool get isPastLifespan {
    if (!isItEquipment) return false;
    final limit = DateTime(
      purchaseDate.year + itEquipmentLifespanYears,
      purchaseDate.month,
      purchaseDate.day,
    );
    return DateTime.now().isAfter(limit);
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