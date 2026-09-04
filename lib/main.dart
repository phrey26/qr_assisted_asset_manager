import 'package:flutter/material.dart';

import 'models/asset.dart';
import 'models/category.dart';
import 'screens/add_asset_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/register_screen.dart';
import 'screens/requests_screen.dart';
import 'services/api_service.dart';
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
  const AppShell({super.key, required this.user});

  /// The signed-in user's row from `user` (as returned by
  /// `csdo_api/login.php`) — `employee_id`, `full_name`, `email`,
  /// `department`. Threaded down to [ProfileScreen] and used to prefill new
  /// requests.
  final Map<String, dynamic> user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = kTabHome;
  List<AssetItem> _assets = [];

  // The list of asset categories, shared by the Categories tab (cards),
  // the Inventory tab (filter chips), and the Add Asset form (dropdown).
  // Loaded from the backend in [_loadInitialData]; the built-in categories
  // are seeded into the `categories` table the first time the app runs
  // against an empty database. The admin can add more from the Categories
  // tab via [_addCategory].
  List<AssetCategory> _categories = [];

  // categories.php's `value` -> database id, so [_addAsset] can resolve the
  // `category_id` foreign key the backend needs (the AssetCategory/AssetItem
  // models themselves only carry the category's string `value`).
  final Map<String, int> _categoryIds = {};

  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // _loadInitialData's first statement calls setState before its first
    // `await`; called straight from initState (itself invoked while the
    // parent is still building) that would run synchronously during the
    // current build and throw "setState() or markNeedsBuild() called
    // during build". Deferring to the next frame — the same fix
    // [_setIndex] below uses for the same underlying reason — sidesteps
    // that entirely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialData();
    });
  }

  /// Loads categories and assets from the backend. If the `categories`
  /// table is empty (a fresh database), seeds it with the app's four
  /// built-in categories first so their icon/color values always match
  /// Flutter's IconData/Color encoding exactly instead of a hand-typed
  /// guess in schema.sql.
  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      var categoryRows = await ApiService.fetchCategories();
      if (categoryRows.isEmpty) {
        for (final category in AssetCategory.defaults) {
          await ApiService.addCategory(category.toJson());
        }
        categoryRows = await ApiService.fetchCategories();
      }

      final assetRows = await ApiService.fetchAssets();

      final categories = <AssetCategory>[];
      _categoryIds.clear();
      for (final row in categoryRows) {
        categories.add(AssetCategory.fromJson(row));
        _categoryIds[row['value'] as String] = row['id'] as int;
      }

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _assets = assetRows.map(AssetItem.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load data from the server: $e';
        _loading = false;
      });
    }
  }

  /// Shows a brief error message without interrupting whatever the admin
  /// was doing — used after an optimistic local update's matching API call
  /// fails, since the local UI has already moved on by the time the
  /// response comes back.
  void _showSyncError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Lets the shared circular FAB trigger [RequestsScreenState.openNewRequest]
  // without lifting the requests list up into AppShell the way assets are —
  // RequestsScreen keeps owning its own state, and AppShell just reaches
  // into it via this key, the same pattern used for e.g. form/scaffold keys.
  final _requestsKey = GlobalKey<RequestsScreenState>();

  // Lets tapping a category card on the Categories tab jump straight to
  // the Inventory tab with that category already filtered — same
  // GlobalKey pattern as [_requestsKey] above.
  final _inventoryKey = GlobalKey<InventoryScreenState>();

  // Lets the shared "add" FAB and the bottom-left "delete category" FAB
  // trigger [CategoriesScreenState.openAddCategoryDialog] /
  // [CategoriesScreenState.openDeleteCategoryDialog] when the admin is on
  // the Categories tab — same GlobalKey pattern as [_requestsKey] and
  // [_inventoryKey] above.
  final _categoriesKey = GlobalKey<CategoriesScreenState>();

  /// Saves a new asset to the backend, then (once the insert succeeds)
  /// drops it into the local list — the tag ID and category are already
  /// generated/chosen locally, but showing the asset before the insert is
  /// confirmed risks an inventory list that disagrees with the database if
  /// the request fails.
  Future<void> _addAsset(AssetItem asset) async {
    final categoryId = _categoryIds[asset.category];
    if (categoryId == null) {
      _showSyncError('Unknown category "${asset.category}" — could not save the asset.');
      return;
    }
    try {
      final body = asset.toJson()..['category_id'] = categoryId;
      await ApiService.addAsset(body);
      if (!mounted) return;
      setState(() => _assets.insert(0, asset));
    } catch (e) {
      _showSyncError('Could not save the new asset: $e');
    }
  }

  /// Adds a new category, created by the admin via the "Add new category"
  /// dialog on the Categories tab. Immediately available as an Inventory
  /// filter chip and an Add Asset dropdown option, since all three read
  /// from this same list.
  Future<void> _addCategory(AssetCategory category) async {
    try {
      final id = await ApiService.addCategory(category.toJson());
      _categoryIds[category.value] = id;
      if (!mounted) return;
      setState(() => _categories.add(category));
    } catch (e) {
      _showSyncError('Could not save the new category: $e');
    }
  }

  /// Removes a category, once the admin confirms via the "are you sure"
  /// dialog shown by [CategoriesScreen]. Only ever called for a category
  /// with no assets currently filed under it — [CategoriesScreen] blocks
  /// the delete before it gets here otherwise.
  Future<void> _deleteCategory(AssetCategory category) async {
    try {
      await ApiService.deleteCategory(category.value);
      _categoryIds.remove(category.value);
      if (!mounted) return;
      setState(() => _categories.remove(category));
    } catch (e) {
      _showSyncError('Could not delete the category: $e');
    }
  }

  /// Removes an asset from the inventory. Called only after the admin
  /// confirms via the "are you sure" dialog shown by [InventoryScreen] /
  /// [AssetDetailScreen] — e.g. once an asset is broken or otherwise no
  /// longer usable. tagId is unique per asset, so it's used to identify
  /// which one to remove.
  Future<void> _deleteAsset(AssetItem asset) async {
    try {
      await ApiService.deleteAsset(asset.tagId);
      if (!mounted) return;
      setState(() => _assets.removeWhere((item) => item.tagId == asset.tagId));
    } catch (e) {
      _showSyncError('Could not delete the asset: $e');
    }
  }

  /// Changes an asset's status — e.g. flagging it as under maintenance, or
  /// marking it available again once it's fixed. Triggered from the status
  /// chip's menu on the inventory page (list, table, and detail views all
  /// share this one handler). tagId is unique per asset, so it's used to
  /// find the matching item in [_assets] rather than relying on object
  /// identity, which the widgets that call this don't guarantee. Applied
  /// locally right away (the chip's own menu already closed by the time
  /// this runs) and rolled back if the backend rejects it.
  Future<void> _updateAssetStatus(AssetItem asset, AssetStatus status) async {
    final match = _assets.firstWhere((item) => item.tagId == asset.tagId);
    final previousStatus = match.status;
    setState(() => match.status = status);
    try {
      await ApiService.updateAssetStatus(tagId: asset.tagId, status: status.apiValue);
    } catch (e) {
      setState(() => match.status = previousStatus);
      _showSyncError('Could not update the asset\'s status: $e');
    }
  }

  Future<void> _openAddAsset() async {
    final tagId = AssetItem.nextTagId(_assets);
    final AssetItem? asset;
    if (Responsive.isDesktop(context)) {
      // Desktop mockups show "Add new asset" as a centered modal over a
      // dimmed inventory list, rather than navigating to a new page.
      asset = await showDialog<AssetItem>(
        context: context,
        builder: (_) => AddAssetDialog(nextTagId: tagId, categories: _categories),
      );
    } else {
      asset = await Navigator.push<AssetItem>(
        context,
        MaterialPageRoute(
          builder: (_) => AddAssetScreen(nextTagId: tagId, categories: _categories),
        ),
      );
    }
    if (asset != null) _addAsset(asset);
  }

  /// Switches the active tab. Deferred to the next frame (rather than
  /// mutating state directly inside the tap handler) because `pages`
  /// rebuilds every tab's widget tree on each `build()`, and [IndexedStack]
  /// keeps all five tabs (including the asset/request lists' many
  /// InkWell-driven hover regions) mounted at once. Doing that rebuild
  /// synchronously inside the bottom-nav/sidebar tap — itself still being
  /// processed by Flutter's mouse tracker — is what was throwing
  /// "'!_debugDuringDeviceUpdate': is not true" and crashing the app right
  /// as the Inventory/Requests tabs opened.
  void _setIndex(int value) {
    if (value == _index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _index = value);
    });
  }

  /// Switches to the Inventory tab with [category] already selected in its
  /// filter chips. Wired up to [CategoriesScreen]'s category cards.
  void _openCategoryInInventory(String category) {
    _inventoryKey.currentState?.setFilter(category);
    _setIndex(kTabInventory);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _loadInitialData, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      CategoriesScreen(
        key: _categoriesKey,
        assets: _assets,
        categories: _categories,
        onCategoryTap: _openCategoryInInventory,
        onAddCategory: _addCategory,
        onDeleteCategory: _deleteCategory,
      ),
      InventoryScreen(
        key: _inventoryKey,
        assets: _assets,
        categories: _categories,
        onAddAsset: _openAddAsset,
        onDeleteAsset: _deleteAsset,
        onUpdateStatus: _updateAssetStatus,
      ),
      QrScannerScreen(assets: _assets),
      RequestsScreen(key: _requestsKey, currentUser: widget.user),
      ProfileScreen(user: widget.user),
    ];

    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              index: _index,
              onChanged: _setIndex,
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
      // On the Categories tab, a second circular button sits bottom-left
      // (mirroring the bottom-right "add" FAB below) for deleting a
      // category. It's layered on top of the body via Stack/Positioned
      // rather than through Scaffold's own floatingActionButton slot,
      // since that slot only supports one button/location at a time.
      // Sitting inside body (which Scaffold already keeps clear of the
      // bottomNavigationBar) means its 16px bottom margin lines up with
      // the add FAB's own margin above the nav bar.
      body: Stack(
        children: [
          SafeArea(child: IndexedStack(index: _index, children: pages)),
          Positioned(
            left: 16,
            bottom: 16,
            child: _DeleteCategoryFab(
              visible: _index == kTabHome,
              onPressed: () => _categoriesKey.currentState?.openDeleteCategoryDialog(),
            ),
          ),
        ],
      ),
      floatingActionButton: switch (_index) {
        kTabHome => _AddFab(
            onPressed: () => _categoriesKey.currentState?.openAddCategoryDialog(),
          ),
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
        onChanged: _setIndex,
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
      // Without an explicit tag, every [FloatingActionButton] falls back to
      // the same shared default hero tag. This FAB and [_DeleteCategoryFab]
      // below are both mounted at once on mobile (this one lives in
      // Scaffold's own floatingActionButton slot; that one sits in the
      // body's Stack, always present and just fading/scaling out when not
      // on the Categories tab) — so with no tag, the two collided and
      // Flutter's Hero controller threw "multiple heroes that share the
      // same tag" the moment a route was pushed (opening an asset/request
      // detail screen) while both were in the tree. Distinct tags give
      // each FAB its own identity instead.
      heroTag: 'app-add-fab',
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

/// Circular "delete category" button shown bottom-left on the Categories
/// tab (mobile only — desktop uses the toolbar button next to "Add
/// category" instead). Styled after the red trash-in-a-circle icon
/// already used for the delete confirmation dialogs elsewhere in the app
/// (see [AppTheme.redTint]/[Colors.redAccent] in
/// delete_category_dialog.dart and select_category_to_delete_dialog.dart),
/// so the "this removes something" affordance reads the same wherever it
/// shows up — just white-on-red instead of that badge's red-on-red-tint,
/// to still read clearly as a FAB.
///
/// Unlike [_AddFab], this button isn't wired into Scaffold's own
/// floatingActionButton slot (that slot only holds one widget/location at
/// a time, and the add FAB already occupies it), so it doesn't get
/// Scaffold's automatic scale-and-rotate transition for free when it
/// appears or disappears between tabs. [visible] drives a matching
/// scale/rotate animation by hand — same duration and easing curves
/// Scaffold's default [FloatingActionButtonAnimator] uses for its own
/// FAB — so the two buttons pop in and out the same way instead of the
/// add FAB animating while this one just blinks on/off.
class _DeleteCategoryFab extends StatefulWidget {
  const _DeleteCategoryFab({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  State<_DeleteCategoryFab> createState() => _DeleteCategoryFabState();
}

class _DeleteCategoryFabState extends State<_DeleteCategoryFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.visible ? 1 : 0,
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  // A subtle quarter-turn-ish twist alongside the scale, matching the
  // slight rotation Scaffold's default FAB transition adds as it pops in.
  late final Animation<double> _turns = Tween<double>(begin: 0.75, end: 1).animate(_scale);

  @override
  void didUpdateWidget(covariant _DeleteCategoryFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: ScaleTransition(
        scale: _scale,
        child: RotationTransition(
          turns: _turns,
          child: FloatingActionButton(
            // See the matching note on [_AddFab.heroTag] — this FAB is
            // always mounted (just visually hidden via IgnorePointer +
            // animation, not removed from the tree), so it needs its own
            // distinct tag rather than colliding with _AddFab's default.
            heroTag: 'app-delete-category-fab',
            onPressed: widget.onPressed,
            backgroundColor: Colors.redAccent,
            elevation: 4,
            highlightElevation: 6,
            tooltip: 'Delete category',
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
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

    // The bar used to be a fixed 88px tall regardless of device, with no
    // regard for the bottom system inset (the on-screen 3-button nav bar
    // or gesture-handle strip). On a phone with a tall system nav bar that
    // left too little clearance above it — the buttons in this bar and
    // the system's own nav buttons ended up close enough to visually
    // collide, with icon/label sizes also identical on every phone
    // regardless of how much width/height it actually had. `contentHeight`
    // scales with the device, and the bottom system inset is added as its
    // own SafeArea padding underneath the bar's content instead of being
    // ignored.
    final scale = Responsive.uiScale(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final contentHeight = Responsive.bottomNavContentHeight(context);
    final scannerSize = 60 * scale;

    return BottomAppBar(
      height: contentHeight + bottomInset,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: contentHeight,
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
                        width: scannerSize,
                        height: scannerSize,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.$1, color: Colors.white, size: 26 * scale),
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
                        size: 22 * scale,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 11 * scale,
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
        ),
      ),
    );
  }
}