import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

/// Attachment block for a single photo or scan of the filled-out, signed
/// CSDO Request Form. Replaces asking for four separate signature images —
/// one clear photo of the form already shows every signature on it, same
/// as the paper form works today.
class RequestFormField extends StatefulWidget {
  const RequestFormField({
    super.key,
    this.imageBytes,
    required this.onImageChanged,
  });

  /// The currently-attached photo/scan of the request form, if any.
  final Uint8List? imageBytes;

  final ValueChanged<Uint8List?> onImageChanged;

  @override
  State<RequestFormField> createState() => _RequestFormFieldState();
}

class _RequestFormFieldState extends State<RequestFormField> {
  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      widget.onImageChanged(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = widget.imageBytes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CSDO Request Form',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Attach a scan or photo of the filled-out, signed form — all four signatures should be visible in it.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 160,
              color: Colors.white,
              child: imageBytes == null
                  ? const Center(
                      child: Icon(Icons.description_outlined, color: AppTheme.muted, size: 32),
                    )
                  : Image.memory(imageBytes, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Capture'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Upload scan'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              if (imageBytes != null)
                TextButton.icon(
                  onPressed: () => widget.onImageChanged(null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}