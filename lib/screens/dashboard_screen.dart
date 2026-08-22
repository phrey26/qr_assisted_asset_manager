import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCsdoAppBar(
        leadingIcon: Icons.grid_view_rounded,
        title: 'CSDO Asset System',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Stat cards (2x2 on mobile) ----
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: const [
              _StatCard(label: 'Total assets', value: '284', color: AppColors.textPrimary),
              _StatCard(label: 'Available', value: '201', color: AppColors.green),
              _StatCard(label: 'Pending requests', value: '12', color: AppColors.orange),
              _StatCard(label: 'Low stock', value: '7', color: AppColors.red),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Recent asset requests ----
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(title: 'Recent asset requests'),
                const SizedBox(height: 14),
                const _RequestRow(
                  name: 'Juan dela Cruz',
                  asset: 'Projector #3',
                  date: 'May 17',
                  label: 'Pending',
                  tone: BadgeTone.orange,
                ),
                const Divider(height: 22),
                const _RequestRow(
                  name: 'Maria Santos',
                  asset: 'Laptop #7',
                  date: 'May 16',
                  label: 'Approved',
                  tone: BadgeTone.green,
                ),
                const Divider(height: 22),
                const _RequestRow(
                  name: 'Pedro Reyes',
                  asset: 'Printer #1',
                  date: 'May 15',
                  label: 'Rejected',
                  tone: BadgeTone.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Low stock alerts ----
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(title: 'Low stock alerts'),
                const SizedBox(height: 12),
                const _LowStockRow(name: 'Bond paper (A4)', left: '3 left'),
                const SizedBox(height: 10),
                const _LowStockRow(name: 'Whiteboard markers', left: '5 left'),
                const SizedBox(height: 10),
                const _LowStockRow(name: 'Extension cords', left: '4 left'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Quick actions ----
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(title: 'Quick actions'),
                const SizedBox(height: 12),
                _QuickActionButton(
                  icon: Icons.grid_view_rounded,
                  label: 'Scan QR code',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _QuickActionButton(
                  icon: Icons.add,
                  label: 'Add new asset',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _QuickActionButton(
                  icon: Icons.bar_chart_rounded,
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final String name;
  final String asset;
  final String date;
  final String label;
  final BadgeTone tone;

  const _RequestRow({
    required this.name,
    required this.asset,
    required this.date,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('$asset · $date',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        StatusBadge(label: label, tone: tone),
      ],
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final String name;
  final String left;

  const _LowStockRow({required this.name, required this.left});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 13.5)),
        StatusBadge(label: left, tone: BadgeTone.orange),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.accent),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
