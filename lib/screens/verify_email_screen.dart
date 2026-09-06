import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Code-entry screen shown right after registering, or when a login attempt
/// comes back "email not verified". On success the account is active and the
/// user is signed straight in.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.devCode,
    this.infoMessage,
  });

  static const routeName = '/verify-email';

  final String email;

  /// Present only when the backend is in mail dev mode (no SMTP set up).
  final String? devCode;

  /// Optional context line, e.g. "You still need to verify this email."
  final String? infoMessage;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _error;
  String? _notice;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (widget.devCode != null) {
      _codeController.text = widget.devCode!;
      _notice = 'Dev mode: code ${widget.devCode} was pre-filled (no email sent).';
    } else if (widget.infoMessage != null) {
      _notice = widget.infoMessage;
    }
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_submitting) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = await ApiService.verifyEmail(email: widget.email, code: code);
      await SessionStore.save(user);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AppShell(user: user)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendIn > 0) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await ApiService.resendCode(email: widget.email, purpose: 'verify');
      if (!mounted) return;
      setState(() {
        _notice = result.devCode != null
            ? 'Dev mode: new code is ${result.devCode} (no email sent).'
            : result.message;
        if (result.devCode != null) _codeController.text = result.devCode!;
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code we sent to ${widget.email}.',
      children: [
        if (_notice != null) AuthMessage(_notice, success: true),
        AuthMessage(_error),
        const AuthFieldLabel('Verification code'),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
            color: AppTheme.darkGreen,
          ),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _verify,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Verify & continue'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_resendIn > 0 || _resending) ? null : _resend,
          child: Text(
            _resending
                ? 'Sending…'
                : _resendIn > 0
                    ? 'Resend code in ${_resendIn}s'
                    : 'Resend code',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
