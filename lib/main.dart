import 'package:flutter/material.dart';

import 'models/asset.dart';
import 'screens/add_asset_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_theme.dart';

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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final List<AssetItem> _assets = AssetItem.samples;

  void _addAsset(AssetItem asset) {
    setState(() => _assets.insert(0, asset));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CategoriesScreen(assets: _assets),
      InventoryScreen(assets: _assets),
      QrScannerScreen(assets: _assets),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              onPressed: () async {
                final asset = await Navigator.push<AssetItem>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddAssetScreen(nextTagId: AssetItem.nextTagId(_assets)),
                  ),
                );
                if (asset != null) _addAsset(asset);
              },
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
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
      (Icons.home_outlined, Icons.home, 'Home'),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
      (Icons.qr_code_scanner, Icons.qr_code_scanner, ''),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];

    return BottomAppBar(
      height: 88,
      padding: EdgeInsets.zero,
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = index == i;
          final item = items[i];
          if (i == 2) {
            return Expanded(
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => onChanged(i),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: Colors.white, size: 28),
                  ),
                ),
              ),
            );
          }
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.$2 : item.$1,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: TextStyle(
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
        }),
      ),
    );
  }
}
