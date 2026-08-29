import 'package:flutter/material.dart';

import 'models/asset.dart';
import 'screens/add_asset_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/register_screen.dart';
import 'screens/requests_screen.dart';
import 'theme/app_theme.dart';
import 'utils/responsive.dart';
import 'widgets/add_asset_dialog.dart';
import 'widgets/brand_mark.dart';

void main() {
  runApp(const AssetManagementApp());
}

class AssetManagementApp extends StatelessWidget {
  const AssetManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Asset Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
      },
    );
  }
}

// Tab indices shared between the mobile bottom nav and the desktop sidebar
// so both can drive the same IndexedStack.
const int kTabHome = 0;
const int kTabInventory = 1;
const int kTabScanner = 2;
const int kTabRequests = 3;
const int kTabProfile = 4;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = kTabHome;
  final List<AssetItem> _assets = AssetItem.samples;

  // Lets the shared circular FAB trigger [RequestsScreenState.openNewRequest]
  // without lifting the requests list up into AppShell the way assets are —
  // RequestsScreen keeps owning its own state, and AppShell just reaches
  // into it via this key, the same pattern used for e.g. form/scaffold keys.
  final _requestsKey = GlobalKey<RequestsScreenState>();

  // Lets tapping a category card on the Categories tab jump straight to
  // the Inventory tab with that category already filtered — same
  // GlobalKey pattern as [_requestsKey] above.
  final _inventoryKey = GlobalKey<InventoryScreenState>();

  void _addAsset(AssetItem asset) {
    setState(() => _assets.insert(0, asset));
  }

  /// Removes an asset from the inventory. Called only after the admin
  /// confirms via the "are you sure" dialog shown by [InventoryScreen] /
  /// [AssetDetailScreen] — e.g. once an asset is broken or otherwise no
  /// longer usable. tagId is unique per asset, so it's used to identify
  /// which one to remove.
  void _deleteAsset(AssetItem asset) {
    setState(() => _assets.removeWhere((item) => item.tagId == asset.tagId));
  }

  /// Changes an asset's status — e.g. flagging it as under maintenance, or
  /// marking it available again once it's fixed. Triggered from the status
  /// chip's menu on the inventory page (list, table, and detail views all
  /// share this one handler). tagId is unique per asset, so it's used to
  /// find the matching item in [_assets] rather than relying on object
  /// identity, which the widgets that call this don't guarantee.
  void _updateAssetStatus(AssetItem asset, AssetStatus status) {
    setState(() {
      final match = _assets.firstWhere((item) => item.tagId == asset.tagId);
      match.status = status;
    });
  }

  Future<void> _openAddAsset() async {
    final tagId = AssetItem.nextTagId(_assets);
    final AssetItem? asset;
    if (Responsive.isDesktop(context)) {
      // Desktop mockups show "Add new asset" as a centered modal over a
      // dimmed inventory list, rather than navigating to a new page.
      asset = await showDialog<AssetItem>(
        context: context,
        builder: (_) => AddAssetDialog(nextTagId: tagId),
      );
    } else {
      asset = await Navigator.push<AssetItem>(
        context,
        MaterialPageRoute(builder: (_) => AddAssetScreen(nextTagId: tagId)),
      );
    }
    if (asset != null) _addAsset(asset);
  }

  /// Switches to the Inventory tab with [category] already selected in its
  /// filter chips. Wired up to [CategoriesScreen]'s category cards.
  void _openCategoryInInventory(String category) {
    _inventoryKey.currentState?.setFilter(category);
    setState(() => _index = kTabInventory);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CategoriesScreen(assets: _assets, onCategoryTap: _openCategoryInInventory),
      InventoryScreen(
        key: _inventoryKey,
        assets: _assets,
        onAddAsset: _openAddAsset,
        onDeleteAsset: _deleteAsset,
        onUpdateStatus: _updateAssetStatus,
      ),
      QrScannerScreen(assets: _assets),
      RequestsScreen(key: _requestsKey),
      const ProfileScreen(),
    ];

    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              index: _index,
              onChanged: (value) => setState(() => _index = value),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF6F5F0),
                child: SafeArea(
                  child: IndexedStack(index: _index, children: pages),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: switch (_index) {
        kTabInventory => _AddFab(onPressed: _openAddAsset),
        kTabRequests => _AddFab(
            onPressed: () => _requestsKey.currentState?.openNewRequest(),
          ),
        _ => null,
      },
      // endFloat sits bottom-right and, with a bottomNavigationBar present,
      // Scaffold automatically floats it just above the bar (standard 16px
      // margin) instead of overlapping it. centerDocked previously placed
      // it dead-center, directly on top of the centered QR scanner button.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }
}

/// Gradient "add" FAB matching the app's green palette, reused for both
/// "Add asset" (inventory tab) and "New request" (requests tab) since they
/// share the same circular plus-button treatment. A plain
/// [FloatingActionButton] only supports a solid [backgroundColor], so this
/// makes the button's background transparent and paints the gradient on an
/// [Ink] child instead, which keeps the normal Material ripple/elevation.
class _AddFab extends StatelessWidget {
  const _AddFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      elevation: 4,
      highlightElevation: 6,
      child: Ink(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.darkGreen],
          ),
        ),
        child: const SizedBox.expand(
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

/// Fixed-width sidebar navigation used on desktop/wide layouts, matching
/// the QREMS hi-fi desktop mockups (brand mark, nav list, active item
/// highlighted in mint).
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _navItems = [
    (Icons.grid_view_outlined, Icons.grid_view, 'Categories', kTabHome),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory', kTabInventory),
    (Icons.assignment_outlined, Icons.assignment, 'Requests', kTabRequests),
    (Icons.qr_code_scanner, Icons.qr_code_scanner, 'Scanner', kTabScanner),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.border, width: 1.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 26),
                child: Row(
                  children: const [
                    BrandMark(size: 34),
                    SizedBox(width: 10),
                    Text(
                      'QREMS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.4,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in _navItems)
                _SidebarItem(
                  outlineIcon: item.$1,
                  filledIcon: item.$2,
                  label: item.$3,
                  selected: index == item.$4,
                  onTap: () => onChanged(item.$4),
                ),
              const Spacer(),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 6),
              _SidebarItem(
                outlineIcon: Icons.person_outline,
                filledIcon: Icons.person,
                label: 'Profile',
                selected: index == kTabProfile,
                onTap: () => onChanged(kTabProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.mint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? filledIcon : outlineIcon,
                  size: 20,
                  color: selected ? AppTheme.primary : const Color(0xFF9B9A91),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.primary : const Color(0xFF9B9A91),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (Icons.home_outlined, Icons.home, 'Home', kTabHome),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory', kTabInventory),
      (Icons.qr_code_scanner, Icons.qr_code_scanner, '', kTabScanner),
      (Icons.assignment_outlined, Icons.assignment, 'Requests', kTabRequests),
      (Icons.person_outline, Icons.person, 'Profile', kTabProfile),
    ];

    return BottomAppBar(
      height: 88,
      padding: EdgeInsets.zero,
      child: Row(
        children: items.map((item) {
          final selected = index == item.$4;
          if (item.$4 == kTabScanner) {
            return Expanded(
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => onChanged(item.$4),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: Colors.white, size: 26),
                  ),
                ),
              ),
            );
          }
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(item.$4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.$2 : item.$1,
                    size: 22,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}