import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
          child: Column(
            children: [
              const Row(
                children: [
                  BrandMark(size: 84),
                  SizedBox(width: 28),
                  Expanded(
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
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account created successfully.')),
                  );
                  Navigator.pushReplacementNamed(
                    context,
                    LoginScreen.routeName,
                  );
                },
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
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
