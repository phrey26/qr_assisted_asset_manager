class AssetItem {
  final String name;
  final String id;
  final String category;
  final int quantity;
  final String status;
  final String location;

  const AssetItem({
    required this.name,
    required this.id,
    required this.category,
    required this.quantity,
    required this.status,
    this.location = 'Supply Room A',
  });
}

const demoAssets = [
  AssetItem(
    name: 'Projector',
    id: 'CSDO-2024-0031',
    category: 'Equipment',
    quantity: 3,
    status: 'Available',
  ),

  AssetItem(
    name: 'Laptop',
    id: 'CSDO-2024-0007',
    category: 'Equipment',
    quantity: 8,
    status: 'In use',
  ),

  AssetItem(
    name: 'Bond paper (A4)',
    id: 'CSDO-2024-0055',
    category: 'Supplies',
    quantity: 3,
    status: 'Low stock',
  ),

  AssetItem(
    name: 'Whiteboard marker',
    id: 'CSDO-2024-0019',
    category: 'Supplies',
    quantity: 5,
    status: 'Low stock',
  ),
];