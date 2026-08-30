import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/brand_mark.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idController = TextEditingController(text: 'CSDO-00214');
  final passwordController = TextEditingController(text: 'password123');
  bool obscure = true;

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (isDesktop) {
      return _DesktopLoginView(
        idController: idController,
        passwordController: passwordController,
        obscure: obscure,
        onToggleObscure: () => setState(() => obscure = !obscure),
        onLogin: _login,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // The keyboard would otherwise shrink the available height and
      // trigger the same "not everything fits" problem this screen is
      // built to avoid. The form fields are simple enough that nothing is
      // lost by leaving the layout as-is and letting the OS handle the
      // keyboard overlay instead of resizing the body.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Mobile: instead of scrolling (or guessing at a scale factor
            // that still overflows on very short phones), lay the content
            // out at its natural/full size inside a fixed-size canvas,
            // then let FittedBox scale that whole canvas down (or up) as
            // one unit to exactly fit whatever height/width is actually
            // available. This guarantees every element — logo down to the
            // "Register" link — is on screen with no scrolling, on any
            // phone size.
            const designWidth = 400.0;
            const designHeight = 760.0;
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: designWidth,
                  height: designHeight,
                  child: _MobileLoginForm(
                    idController: idController,
                    passwordController: passwordController,
                    obscure: obscure,
                    onToggleObscure: () => setState(() => obscure = !obscure),
                    onLogin: _login,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The mobile login form, laid out at full/natural size. The parent
/// `FittedBox` (in `_LoginScreenState.build`) takes care of scaling this
/// down to fit any phone without ever needing to scroll.
class _MobileLoginForm extends StatelessWidget {
  const _MobileLoginForm({
    required this.idController,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final TextEditingController idController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandMark(size: 120),
              const SizedBox(height: 40),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to manage campus assets',
                style: TextStyle(color: AppTheme.muted, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              _FormLabel('Employee ID', fontSize: 20),
              TextField(
                controller: idController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 30),
              _FormLabel('Password', fontSize: 20),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Log in'),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  RegisterScreen.routeName,
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: AppTheme.muted, fontSize: 18),
                    children: [
                      const TextSpan(text: 'Need an account? '),
                      TextSpan(
                        text: 'Register',
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
    );
  }
}

/// A fresh, modern desktop login screen: a split view with a brand/feature
/// panel on the left and the sign-in form on the right. Each side scrolls
/// independently and is wrapped with its own `minHeight` safety net, so a
/// short/maximized browser window can never overflow the way the old
/// single fixed-size card used to.
class _DesktopLoginView extends StatelessWidget {
  const _DesktopLoginView({
    required this.idController,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final TextEditingController idController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

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
                if (showBrandPanel) const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(
                  flex: showBrandPanel ? 4 : 1,
                  child: _FormPanel(
                    idController: idController,
                    passwordController: passwordController,
                    obscure: obscure,
                    onToggleObscure: onToggleObscure,
                    onLogin: onLogin,
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

/// Left-hand brand/feature panel for the desktop split view.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = [
    (Icons.qr_code_scanner_rounded, 'Scan a QR code to check assets in or out in seconds'),
    (Icons.inventory_2_outlined, 'Track every item\'s location, condition, and history'),
    (Icons.fact_check_outlined, 'Keep audit-ready records without a single paper form'),
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
          // Soft decorative circles, purely for visual interest.
          Positioned(
            top: -80,
            right: -60,
            child: _decorativeCircle(220, AppTheme.primary.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -100,
            left: -60,
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
                            Icons.qr_code_2_rounded,
                            color: AppTheme.darkGreen,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'QR-Assisted Asset\nManagement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'The paperless way to check, track, and account for every '
                          'campus asset your office manages.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 17,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        for (final feature in _features) ...[
                          _FeatureRow(icon: feature.$1, label: feature.$2),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

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

/// Right-hand sign-in form panel for the desktop split view.
class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.idController,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final TextEditingController idController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

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
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to manage campus assets',
                        style: TextStyle(color: AppTheme.muted, fontSize: 16),
                      ),
                      const SizedBox(height: 40),
                      _FormLabel('Employee ID', fontSize: 15),
                      TextField(
                        controller: idController,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 22),
                      _FormLabel('Password', fontSize: 15),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            onPressed: onToggleObscure,
                            icon: Icon(
                              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onLogin,
                          child: const Text('Log in'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            RegisterScreen.routeName,
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: AppTheme.muted, fontSize: 15),
                              children: [
                                const TextSpan(text: 'Need an account? '),
                                TextSpan(
                                  text: 'Register',
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
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text, {this.fontSize = 20});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}