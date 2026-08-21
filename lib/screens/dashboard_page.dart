import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/card_container.dart';
import '../widgets/quick_action.dart';
import '../widgets/section_title.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(
            title: 'CSDO Asset System',
            subtitle: 'Asset and equipment management',
          ),

          // Statistics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: const [
                StatCard(
                  title: 'Total assets',
                  value: '284',
                  icon: Icons.inventory_2_outlined,
                ),
                StatCard(
                  title: 'Available',
                  value: '201',
                  valueColor: Color(0xFF69B52E),
                  icon: Icons.check_circle_outline,
                ),
                StatCard(
                  title: 'Pending requests',
                  value: '12',
                  valueColor: Color(0xFFE08A16),
                  icon: Icons.pending_actions,
                ),
                StatCard(
                  title: 'Low stock',
                  value: '7',
                  valueColor: Color(0xFFE14C4C),
                  icon: Icons.warning_amber_outlined,
                ),
              ],
            ),
          ),

          // Recent requests
          const SectionTitle(
            title: 'Recent asset requests',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  RequestRow(
                    person: 'Juan dela Cruz',
                    asset: 'Projector #3',
                    date: 'May 17',
                    status: 'Pending',
                  ),
                  RequestRow(
                    person: 'Maria Santos',
                    asset: 'Laptop #7',
                    date: 'May 16',
                    status: 'Approved',
                  ),
                  RequestRow(
                    person: 'Pedro Reyes',
                    asset: 'Printer #1',
                    date: 'May 15',
                    status: 'Rejected',
                  ),
                ],
              ),
            ),
          ),

          // Low stock
          const SectionTitle(
            title: 'Low stock alerts',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  StockRow(
                    name: 'Bond paper (A4)',
                    quantity: '3 left',
                  ),
                  StockRow(
                    name: 'Whiteboard markers',
                    quantity: '5 left',
                  ),
                  StockRow(
                    name: 'Extension cords',
                    quantity: '4 left',
                  ),
                ],
              ),
            ),
          ),

          // Quick actions
          const SectionTitle(
            title: 'Quick actions',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                QuickAction(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan QR code',
                  onTap: () {},
                ),
                QuickAction(
                  icon: Icons.add,
                  label: 'Add new asset',
                  onTap: () {},
                ),
                QuickAction(
                  icon: Icons.bar_chart,
                  label: 'Generate report',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RequestRow extends StatelessWidget {
  final String person;
  final String asset;
  final String date;
  final String status;

  const RequestRow({
    super.key,
    required this.person,
    required this.asset,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  asset,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            date,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: status),
        ],
      ),
    );
  }
}

class StockRow extends StatelessWidget {
  final String name;
  final String quantity;

  const StockRow({
    super.key,
    required this.name,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StatusBadge(
            label: quantity,
            type: StatusType.lowStock,
          ),
        ],
      ),
    );
  }
}