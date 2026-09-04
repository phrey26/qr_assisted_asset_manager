import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/brand_mark.dart';
import '../widgets/page_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  /// The signed-in user's row from `user` (as returned by
  /// `csdo_api/login.php`) — `employee_id`, `full_name`, `email`,
  /// `department`.
  final Map<String, dynamic> user;

  String get _name => (user['full_name'] as String?) ?? '';
  String get _employeeId => (user['employee_id'] as String?) ?? '';
  String get _department => (user['department'] as String?) ?? '';
  String get _email => (user['email'] as String?) ?? '';

  void _logOut(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Responsive.isDesktop(context)
        ? _desktopBody(context)
        : _mobileBody(context);
  }

  /// Original mobile presentation, unchanged: a single centered column of
  /// bordered info boxes with a full-width "Log out" button underneath.
  Widget _mobileBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 52, 28, 120),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: Column(
              children: [
                const BrandMark(size: 100),
                const SizedBox(height: 22),
                Text(
                  _name,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _employeeId,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 17),
                ),
                const SizedBox(height: 42),
                _item(Icons.badge_outlined, 'Employee ID', _employeeId),
                _item(Icons.business_outlined, 'Department', _department),
                _item(Icons.email_outlined, 'Work email', _email),
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
                    onPressed: () => _logOut(context),
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

  /// Desktop presentation: a page header (matching Requests/Inventory) with
  /// the "Log out" action on the header row itself, and the account details
  /// laid out as a proper two-column settings page — a compact profile
  /// summary card alongside a wider account-information card — rather than
  /// the same narrow, centered stack of boxes the mobile layout uses just
  /// scaled up.
  Widget _desktopBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 42, 48, 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: PageHeader(
                      title: 'Profile',
                      subtitle: 'Manage your account details',
                      showMark: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      onPressed: () => _logOut(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Log out'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppTheme.primary, width: 2),
                        foregroundColor: AppTheme.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: _summaryCard()),
                  const SizedBox(width: 28),
                  Expanded(child: _accountInfoCard()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        children: [
          const BrandMark(size: 88),
          const SizedBox(height: 20),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _employeeId,
            style: const TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.mint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _department,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account information',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          _accountRow(Icons.badge_outlined, 'Employee ID', _employeeId),
          _accountRow(Icons.business_outlined, 'Department', _department),
          _accountRow(Icons.email_outlined, 'Work email', _email, isLast: true),
        ],
      ),
    );
  }

  Widget _accountRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Container(height: 1.5, color: AppTheme.border),
      ],
    );
  }
}