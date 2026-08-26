import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/brand_mark.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 52, 28, 120),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 460 : double.infinity),
            child: Column(
              children: [
                const BrandMark(size: 100),
                const SizedBox(height: 22),
                const Text(
                  'Juan Dela Cruz',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'CSDO-00214',
                  style: TextStyle(color: AppTheme.muted, fontSize: 17),
                ),
                const SizedBox(height: 42),
                _item(Icons.badge_outlined, 'Employee ID', 'CSDO-00214'),
                _item(Icons.business_outlined, 'Department', 'Campus Services (CSDO)'),
                _item(Icons.email_outlined, 'Work email', 'jdelacruz@hau.edu.ph'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
