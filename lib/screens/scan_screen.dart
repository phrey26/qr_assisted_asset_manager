import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/status_badge.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCsdoAppBar(
        leadingIcon: Icons.qr_code_scanner_rounded,
        title: 'Scan asset',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Camera viewfinder ----
          Container(
            height: 220,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
                width: 1.4,
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_outlined,
                    size: 34, color: AppColors.textMuted),
                SizedBox(height: 10),
                Text(
                  'Camera viewfinder\nappears here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Start camera scan'),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or enter manually',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          const TextField(
            decoration: InputDecoration(hintText: 'Asset ID / QR code...'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search asset'),
          ),
          const SizedBox(height: 20),

          // ---- Asset details after scan ----
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(title: 'Asset details (after scan)'),
                const SizedBox(height: 14),
                const _DetailRow(label: 'Asset name', value: 'Projector #3'),
                const SizedBox(height: 12),
                const _DetailRow(label: 'Asset ID', value: 'CSDO-2024-0031'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Status',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          SizedBox(height: 6),
                          StatusBadge(label: 'Available', tone: BadgeTone.green),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _DetailRow(label: 'Location', value: 'Supply Room A'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Update'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('View history'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Recent scan history ----
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(title: 'Recent scan history'),
                const SizedBox(height: 14),
                const _ScanHistoryRow(
                  asset: 'Laptop #7',
                  by: 'M. Santos',
                  time: '10:42 AM',
                  label: 'Checked out',
                  tone: BadgeTone.blue,
                ),
                const Divider(height: 24),
                const _ScanHistoryRow(
                  asset: 'Projector #3',
                  by: 'J. dela Cruz',
                  time: '9:15 AM',
                  label: 'Returned',
                  tone: BadgeTone.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ScanHistoryRow extends StatelessWidget {
  final String asset;
  final String by;
  final String time;
  final String label;
  final BadgeTone tone;

  const _ScanHistoryRow({
    required this.asset,
    required this.by,
    required this.time,
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
              Text(asset,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('$by · $time',
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
