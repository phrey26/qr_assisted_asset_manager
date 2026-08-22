import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'scan_screen.dart';
import 'request_screen.dart';

/// Bottom-nav shell. The original desktop wireframes use a left icon rail;
/// on mobile that becomes a bottom navigation bar with the same four
/// destinations (Dashboard, Inventory, Scan, Requests).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    InventoryScreen(),
    ScanScreen(),
    RequestScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: AppColors.textMuted,
            selectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11.5),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Inventory',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner_rounded),
                label: 'Scan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.description_outlined),
                label: 'Requests',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
