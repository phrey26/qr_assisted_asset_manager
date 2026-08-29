import 'package:flutter/material.dart';

import '../models/asset_request.dart';
import '../theme/app_theme.dart';

/// Read-only rendering of one "signature over printed name" block, the way
/// it appears on the paper borrow slip: the scanned signature image sits
/// above a ruled line, with the printed name and role underneath it.
/// Shown with a dashed placeholder when that person hasn't signed yet.
class SignatureLine extends StatelessWidget {
  const SignatureLine({super.key, required this.role, required this.signatory});

  final SignatoryRole role;
  final Signatory signatory;

  @override
  Widget build(BuildContext context) {
    final signed = signatory.hasSigned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 56,
          width: double.infinity,
          child: signed
              ? Image.memory(signatory.imageBytes!, fit: BoxFit.contain)
              : Center(
                  child: Text(
                    'Not yet signed',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Container(height: 1.5, color: AppTheme.border),
        const SizedBox(height: 6),
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
        if (signed) ...[
          const SizedBox(height: 4),
          const Icon(Icons.check_circle, color: AppTheme.primary, size: 16),
        ],
      ],
    );
  }
}