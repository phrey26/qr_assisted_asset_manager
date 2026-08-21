import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(
          title: 'More',
          subtitle: 'System tools and settings',
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MoreTile(
                icon: Icons.bar_chart_outlined,
                title: 'Reports',
                subtitle:
                    'Asset utilization and request reports',
                onTap: () {},
              ),

              MoreTile(
                icon: Icons.description_outlined,
                title: 'Request history',
                subtitle:
                    'View previous asset requests',
                onTap: () {},
              ),

              MoreTile(
                icon: Icons.policy_outlined,
                title: 'Policies',
                subtitle:
                    'View request and approval policies',
                onTap: () {},
              ),

              MoreTile(
                icon: Icons.notifications_none,
                title: 'Notifications',
                subtitle:
                    'System and request updates',
                onTap: () {},
              ),

              MoreTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle:
                    'Account and application settings',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MoreTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,

        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
          ),
        ),

        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),

        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),

        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}