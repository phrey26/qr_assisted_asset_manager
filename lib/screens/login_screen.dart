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
    return Scaffold(
      backgroundColor: isDesktop ? const Color(0xFFF6F5F0) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(28, isDesktop ? 40 : 70, 28, 40),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 650),
              padding: isDesktop
                  ? const EdgeInsets.all(40)
                  : EdgeInsets.zero,
              decoration: isDesktop
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border, width: 1.5),
                    )
                  : null,
              child: Column(
              children: [
                const BrandMark(size: 120),
                const SizedBox(height: 40),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage campus assets',
                  style: TextStyle(color: AppTheme.muted, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 65),
                _label('Employee ID'),
                TextField(
                  controller: idController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 30),
                _label('Password'),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
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
                    child: const Text(
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
                  onPressed: _login,
                  child: const Text('Log in'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    RegisterScreen.routeName,
                  ),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppTheme.muted, fontSize: 18),
                      children: [
                        TextSpan(text: 'Need an account? '),
                        TextSpan(
                          text: 'Register',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
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

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
}
