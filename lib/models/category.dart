import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A category assets can be organized under. Shown as a card on the
/// Categories tab, and offered as a filter chip on Inventory and as a
/// dropdown option on the Add Asset form — all three stay in sync because
/// they all read from the same list of categories (owned by [AppShell] and
/// passed down), rather than each hard-coding its own.
@immutable
class AssetCategory {
  const AssetCategory({
    required this.displayName,
    required this.value,
    required this.icon,
    required this.color,
  });

  /// Label shown on the category card (e.g. 'Vehicles').
  final String displayName;

  /// Canonical value stored on [AssetItem.category] / matched against the
  /// inventory filter chips and add-asset dropdown (case-insensitively).
  /// Kept separate from [displayName] only because the app's original
  /// built-in categories don't match their card label exactly ("Vehicles"
  /// vs "Vehicle"). Categories the admin adds just use the same text for
  /// both, entered once.
  final String value;

  final IconData icon;

  final Color color;

  /// Whether [category] (an [AssetItem.category] string) belongs to this
  /// category. Matched case-insensitively since category is free text
  /// elsewhere in the app.
  bool matches(String category) => category.toLowerCase() == value.toLowerCase();

  /// Builds an [AssetCategory] from a `categories` row returned by
  /// `csdo_api/categories.php` (GET).
  factory AssetCategory.fromJson(Map<String, dynamic> json) => AssetCategory(
        displayName: json['display_name'] as String,
        value: json['value'] as String,
        icon: IconData(json['icon_code_point'] as int, fontFamily: 'MaterialIcons'),
        color: Color(json['color_value'] as int),
      );

  /// The fields `csdo_api/categories.php` (POST) expects in its request body.
  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'value': value,
        'icon_code_point': icon.codePoint,
        'color_value': color.toARGB32(),
      };

  /// The categories the app ships with.
  static const defaults = <AssetCategory>[
    AssetCategory(
      displayName: 'IT equipment',
      value: 'IT Equipment',
      icon: Icons.devices_outlined,
      color: AppTheme.mint,
    ),
    AssetCategory(
      displayName: 'Furniture',
      value: 'Furniture',
      icon: Icons.chair_outlined,
      color: AppTheme.cream,
    ),
    AssetCategory(
      displayName: 'Vehicles',
      value: 'Vehicle',
      icon: Icons.directions_car_outlined,
      color: AppTheme.redTint,
    ),
    AssetCategory(
      displayName: 'Tools',
      value: 'Tools',
      icon: Icons.build_outlined,
      color: AppTheme.mint,
    ),
  ];

  /// Curated set of icons the admin can choose from when adding a new
  /// category — covers common asset types without needing a full icon
  /// picker/search.
  static const iconChoices = <IconData>[
    Icons.category_outlined,
    Icons.devices_outlined,
    Icons.laptop_mac_outlined,
    Icons.print_outlined,
    Icons.chair_outlined,
    Icons.kitchen_outlined,
    Icons.directions_car_outlined,
    Icons.local_shipping_outlined,
    Icons.build_outlined,
    Icons.electrical_services_outlined,
    Icons.inventory_2_outlined,
    Icons.school_outlined,
    Icons.medical_services_outlined,
    Icons.book_outlined,
    Icons.camera_alt_outlined,
    Icons.sports_basketball_outlined,
    Icons.checkroom_outlined,
  ];

  /// Curated set of icon-badge tint colors, matching the palette already
  /// used by the built-in categories.
  static const colorChoices = <Color>[AppTheme.mint, AppTheme.cream, AppTheme.redTint];
}