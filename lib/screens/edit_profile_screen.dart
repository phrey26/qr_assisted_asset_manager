import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/email_domains.dart';
import '../widgets/auth_scaffold.dart';

/// Lets an admin edit their own account details — full name, department, and
/// email. Employee ID is the login identity and can't be changed here.
///
/// Pushed from [ProfileScreen]; pops with the refreshed `user` map on a
/// successful save (or nothing if the user backs out).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _nameController =
      TextEditingController(text: (widget.user['full_name'] as String?) ?? '');
  late final _departmentController =
      TextEditingController(text: (widget.user['department'] as String?) ?? '');
  late final _emailController =
      TextEditingController(text: (widget.user['email'] as String?) ?? '');

  String get _employeeId => (widget.user['employee_id'] as String?) ?? '';

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final department = _departmentController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || department.isEmpty || email.isEmpty) {
      setState(() => _error = 'Name, department, and email are all required.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (!isAllowedEmailProvider(email)) {
      setState(() => _error = allowedEmailProvidersError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ApiService.updateProfile(
        employeeId: _employeeId,
        fullName: name,
        department: department,
        email: email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      title: 'Edit profile',
      subtitle: 'Update your account details.',
      children: [
        AuthMessage(_error),
        const AuthFieldLabel('Employee ID'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F5F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border, width: 2),
          ),
          child: Text(
            _employeeId,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Employee ID can't be changed.",
          style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        const AuthFieldLabel('Full name'),
        TextField(controller: _nameController, textCapitalization: TextCapitalization.words),
        const SizedBox(height: 16),
        const AuthFieldLabel('Department'),
        TextField(controller: _departmentController),
        const SizedBox(height: 16),
        const AuthFieldLabel('Work email'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: allowedEmailProvidersHint),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }
}
