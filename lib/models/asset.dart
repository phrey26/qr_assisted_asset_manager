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
  });

  final String name;
  final String tagId;
  final String category;
  final String description;
  final AssetStatus status;

  static List<AssetItem> samples = [
    AssetItem(
      name: 'Epson projector',
      tagId: 'CSDO-IT-0231',
      category: 'IT equipment',
      description: 'Portable projector for classroom presentations.',
      status: AssetStatus.available,
    ),
    AssetItem(
      name: 'Dell Latitude 5420',
      tagId: 'CSDO-IT-0198',
      category: 'IT equipment',
      description: 'Assigned office laptop.',
      status: AssetStatus.inUse,
    ),
    AssetItem(
      name: 'Steel folding chair',
      tagId: 'CSDO-FN-0871',
      category: 'Furniture',
      description: 'Foldable steel chair.',
      status: AssetStatus.available,
    ),
    AssetItem(
      name: 'Split-type aircon',
      tagId: 'CSDO-MT-0042',
      category: 'Maintenance',
      description: 'Wall-mounted split type air-conditioning unit.',
      status: AssetStatus.maintenance,
    ),
  ];

  static String nextTagId(List<AssetItem> assets) {
    var max = 0;
    for (final asset in assets) {
      final match = RegExp(r'(\d+)$').firstMatch(asset.tagId);
      final number = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (number > max) max = number;
    }
    return 'CSDO-IT-${(max + 1).toString().padLeft(4, '0')}';
  }
}
