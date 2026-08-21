import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/card_container.dart';
import '../widgets/section_title.dart';
import '../widgets/status_badge.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          const AppHeader(
            title: 'Scan asset',
            subtitle: 'QR-assisted asset tracking',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  // Camera placeholder
                  Container(
                    height: 270,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222221),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),

                        const Icon(
                          Icons.qr_code_2,
                          size: 105,
                          color: Colors.white,
                        ),

                        const Positioned(
                          bottom: 22,
                          child: Text(
                            'Camera viewfinder',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Camera scanning will be connected later.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                      ),
                      label: const Text(
                        'Start camera scan',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Row(
                    children: [
                      Expanded(
                        child: Divider(),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: Text(
                          'or enter manually',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'Asset ID / QR code...',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'Search asset',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SectionTitle(
            title: 'Asset details',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  const DetailItem(
                    title: 'Asset name',
                    value: 'Projector #3',
                  ),
                  const DetailItem(
                    title: 'Asset ID',
                    value: 'CSDO-2024-0031',
                  ),
                  DetailItem(
                    title: 'Status',
                    child: const StatusBadge(
                      label: 'Available',
                    ),
                  ),
                  const DetailItem(
                    title: 'Location',
                    value: 'Supply Room A',
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.edit_outlined,
                          ),
                          label: const Text('Update'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.history,
                          ),
                          label: const Text('History'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SectionTitle(
            title: 'Recent scan history',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  ScanHistoryRow(
                    asset: 'Laptop #7',
                    user: 'M. Santos',
                    time: '10:42 AM',
                    action: 'Checked out',
                  ),
                  ScanHistoryRow(
                    asset: 'Projector #3',
                    user: 'J. dela Cruz',
                    time: '9:15 AM',
                    action: 'Returned',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailItem extends StatelessWidget {
  final String title;
  final String? value;
  final Widget? child;

  const DetailItem({
    super.key,
    required this.title,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          child ??
              Text(
                value ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
        ],
      ),
    );
  }
}

class ScanHistoryRow extends StatelessWidget {
  final String asset;
  final String user;
  final String time;
  final String action;

  const ScanHistoryRow({
    super.key,
    required this.asset,
    required this.user,
    required this.time,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  asset,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  user,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: action,
          ),
        ],
      ),
    );
  }
}