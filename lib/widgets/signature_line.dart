import 'package:flutter/material.dart';

import '../models/asset_request.dart';
import '../theme/app_theme.dart';

/// Read-only rendering of one "printed name" block from the paper borrow
/// slip: the printed name and role. The actual signature is no longer
/// shown per-person here — it lives on the single attached CSDO Request
/// Form photo (see the form-attachment block on the request detail
/// screen) — so this just lists who the slip is for.
class SignatureLine extends StatelessWidget {
  const SignatureLine({super.key, required this.role, required this.signatory});

  final SignatoryRole role;
  final Signatory signatory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          signatory.name.isEmpty ? '—' : signatory.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          role.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}