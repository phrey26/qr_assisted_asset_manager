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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The desktop layout (a card centered in a wide window) never
            // had a scrolling problem, so it keeps its original fixed
            // sizing untouched. Mobile is where a phone with a shorter
            // screen (or one with a tall status bar / gesture inset) forced
            // a scroll to see the "Log in" button — so on mobile, scale
            // every font size, gap, the logo placeholder, and the button
            // height down (or up) together, proportional to how much
            // vertical room is actually available, instead of using the
            // same fixed sizing on every phone. `SingleChildScrollView`
            // stays in place below as a safety net (e.g. once the
            // keyboard opens), but with this scaling the common case no
            // longer needs it.
            final availableHeight = constraints.maxHeight;
            final double scale = isDesktop
                ? 1.0
                : (availableHeight / 760).clamp(0.72, 1.05).toDouble();
            double sp(double base) => isDesktop ? base : base * scale;
            double gap(double base) => isDesktop ? base : base * scale;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                28,
                isDesktop ? 40 : gap(28),
                28,
                isDesktop ? 40 : gap(28),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: availableHeight),
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
                    child: Theme(
                      // Scales the text fields' vertical padding down to
                      // match the rest of the shrunk layout on shorter
                      // mobile screens; inherited as-is on desktop.
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: isDesktop ? 20 : gap(20).clamp(12.0, 20.0).toDouble(),
                              ),
                            ),
                      ),
                      child: Column(
                        children: [
                          BrandMark(size: isDesktop ? 120 : (120 * scale).clamp(72.0, 130.0).toDouble()),
                          SizedBox(height: gap(40)),
                          Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: sp(36),
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGreen,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: gap(6)),
                          Text(
                            'Sign in to manage campus assets',
                            style: TextStyle(color: AppTheme.muted, fontSize: sp(20)),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: gap(65)),
                          _label('Employee ID', fontSize: sp(20)),
                          TextField(
                            controller: idController,
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: gap(30)),
                          _label('Password', fontSize: sp(20)),
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
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: sp(17),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: gap(20)),
                          ElevatedButton(
                            onPressed: _login,
                            style: isDesktop
                                ? null
                                : ElevatedButton.styleFrom(
                                    minimumSize: Size.fromHeight((64 * scale).clamp(52.0, 64.0).toDouble()),
                                    textStyle: TextStyle(
                                      fontSize: sp(20),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                            child: const Text('Log in'),
                          ),
                          SizedBox(height: gap(24)),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              RegisterScreen.routeName,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(color: AppTheme.muted, fontSize: sp(18)),
                                children: [
                                  const TextSpan(text: 'Need an account? '),
                                  TextSpan(
                                    text: 'Register',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: sp(18),
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
          },
        ),
      ),
    );
  }

  Widget _label(String text, {double fontSize = 20}) => Align(
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