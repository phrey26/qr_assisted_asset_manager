import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/brand_mark.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController(text: 'Juan Dela Cruz');
  final emailController = TextEditingController(text: 'jdelacruz@hau.edu.ph');
  final departmentController =
      TextEditingController(text: 'Campus Services (CSDO)');
  final employeeController = TextEditingController(text: 'CSDO-00214');
  final passwordController = TextEditingController(text: 'password123');

  @override
  void dispose() {
    for (final c in [
      nameController,
      emailController,
      departmentController,
      employeeController,
      passwordController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _createAccount() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully.')),
    );
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (isDesktop) {
      return _DesktopRegisterView(
        nameController: nameController,
        emailController: emailController,
        departmentController: departmentController,
        employeeController: employeeController,
        passwordController: passwordController,
        onCreateAccount: _createAccount,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 84),
                      const SizedBox(width: 28),
                      const Expanded(
                        child: Text(
                          'Create admin account',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  _field('Full name', nameController),
                  _field('Work email', emailController,
                      keyboard: TextInputType.emailAddress),
                  _field('Department', departmentController),
                  _field('Employee ID', employeeController),
                  _field('Password', passwordController, obscure: true),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createAccount,
                      child: const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      LoginScreen.routeName,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: AppTheme.muted, fontSize: 18),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
          ),
        ],
      ),
    );
  }
}

/// A fresh, modern desktop registration screen: a split view with a
/// brand/onboarding panel on the left and the account-creation form on the
/// right. Mirrors the desktop login screen's visual language for a
/// consistent experience, and each side scrolls independently with its own
/// `minHeight` safety net so a short/maximized window never overflows.
class _DesktopRegisterView extends StatelessWidget {
  const _DesktopRegisterView({
    required this.nameController,
    required this.emailController,
    required this.departmentController,
    required this.employeeController,
    required this.passwordController,
    required this.onCreateAccount,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController departmentController;
  final TextEditingController employeeController;
  final TextEditingController passwordController;
  final VoidCallback onCreateAccount;

  static const _brandPanelMinWidth = 1080.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showBrandPanel = constraints.maxWidth >= _brandPanelMinWidth;
            return Row(
              children: [
                if (showBrandPanel) const Expanded(flex: 5, child: _OnboardingPanel()),
                Expanded(
                  flex: showBrandPanel ? 4 : 1,
                  child: _RegisterFormPanel(
                    nameController: nameController,
                    emailController: emailController,
                    departmentController: departmentController,
                    employeeController: employeeController,
                    passwordController: passwordController,
                    onCreateAccount: onCreateAccount,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Left-hand brand/onboarding panel for the desktop registration split view.
class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel();

  static const _steps = [
    (Icons.badge_outlined, 'Verified with your work email and employee ID'),
    (Icons.groups_outlined, 'Invite the rest of your department once you\'re in'),
    (Icons.shield_outlined, 'Admins can manage roles and access at any time'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.darkGreen, Color(0xFF123A2F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -80,
            child: _decorativeCircle(240, AppTheme.primary.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -110,
            right: -70,
            child: _decorativeCircle(260, AppTheme.mint.withValues(alpha: 0.08)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.mint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: AppTheme.darkGreen,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Set up your\nadmin account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bring your office onto QREMS — sign up once and start '
                          'checking assets in and out with a scan.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 17,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        for (final step in _steps) ...[
                          _StepRow(icon: step.$1, label: step.$2),
                          const SizedBox(height: 22),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.mint, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Right-hand account-creation form panel for the desktop split view.
class _RegisterFormPanel extends StatelessWidget {
  const _RegisterFormPanel({
    required this.nameController,
    required this.emailController,
    required this.departmentController,
    required this.employeeController,
    required this.passwordController,
    required this.onCreateAccount,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController departmentController;
  final TextEditingController employeeController;
  final TextEditingController passwordController;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create admin account',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A few details to get your office set up.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 16),
                      ),
                      const SizedBox(height: 36),
                      _field('Full name', nameController),
                      _field('Work email', emailController,
                          keyboard: TextInputType.emailAddress),
                      _field('Department', departmentController),
                      _field('Employee ID', employeeController),
                      _field('Password', passwordController, obscure: true),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onCreateAccount,
                          child: const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            LoginScreen.routeName,
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: AppTheme.muted, fontSize: 15),
                              children: [
                                const TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Log in',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
          ),
        ],
      ),
    );
  }
}