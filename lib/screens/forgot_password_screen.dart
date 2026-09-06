import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// "Forgot password?" flow: enter your email to get a 6-digit reset code,
/// then enter that code plus a new password. Both steps live on this one
/// screen; on success it pops back to the login screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  static const routeName = '/forgot-password';

  /// Prefilled from whatever was typed in the login field, if anything.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Stage { requestCode, setPassword }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(
    text: (widget.initialEmail != null && widget.initialEmail!.contains('@'))
        ? widget.initialEmail
        : '',
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Stage _stage = _Stage.requestCode;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_email.contains('@')) {
      setState(() => _error = 'Enter the email address for your account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await ApiService.requestPasswordReset(email: _email);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.setPassword;
        _notice = result.devCode != null
            ? 'Dev mode: your reset code is ${result.devCode} (no email sent).'
            : result.message;
        if (result.devCode != null) _codeController.text = result.devCode!;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'The two passwords don\'t match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.resetPassword(email: _email, code: code, newPassword: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Sign in with your new password.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: () {
        if (_stage == _Stage.setPassword) {
          setState(() {
            _stage = _Stage.requestCode;
            _error = null;
            _notice = null;
          });
        } else {
          Navigator.of(context).maybePop();
        }
      },
      title: 'Reset your password',
      subtitle: _stage == _Stage.requestCode
          ? 'We\'ll email you a 6-digit code to confirm it\'s you.'
          : 'Enter the code we sent to $_email and choose a new password.',
      children: _stage == _Stage.requestCode ? _requestChildren() : _setPasswordChildren(),
    );
  }

  List<Widget> _requestChildren() {
    return [
      if (_notice != null) AuthMessage(_notice, success: true),
      AuthMessage(_error),
      const AuthFieldLabel('Account email'),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(hintText: 'you@hau.edu.ph'),
        onSubmitted: (_) => _sendCode(),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _busy ? null : _sendCode,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text('Send reset code'),
      ),
    ];
  }

  List<Widget> _setPasswordChildren() {
    return [
      if (_notice != null) AuthMessage(_notice, success: true),
      AuthMessage(_error),
      const AuthFieldLabel('Reset code'),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
          color: AppTheme.darkGreen,
        ),
        decoration: const InputDecoration(counterText: '', hintText: '••••••'),
      ),
      const SizedBox(height: 6),
      const AuthFieldLabel('New password'),
      TextField(
        controller: _passwordController,
        obscureText: _obscure,
        decoration: InputDecoration(
          hintText: 'At least 8 characters',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const AuthFieldLabel('Confirm new password'),
      TextField(
        controller: _confirmController,
        obscureText: _obscure,
        decoration: const InputDecoration(hintText: 'Re-enter the new password'),
        onSubmitted: (_) => _resetPassword(),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _busy ? null : _resetPassword,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text('Reset password'),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: _busy ? null : _sendCode,
        child: const Text('Send a new code', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ];
  }
}
