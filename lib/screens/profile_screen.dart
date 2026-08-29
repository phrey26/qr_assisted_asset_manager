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
                  // The default OutlinedButton has no global theme override
                  // (unlike ElevatedButton, which gets a 64px minimum height
                  // from AppTheme), so left as-is it renders at Material3's
                  // ~40px default — a thin, easy-to-miss target on a phone.
                  // Give it an explicit comfortable height, bolder text, and
                  // a clearer border so it reads (and taps) like a proper
                  // full-size mobile action instead of a stray outline.
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      side: const BorderSide(color: AppTheme.primary, width: 2),
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    icon: const Icon(Icons.logout, size: 22),
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