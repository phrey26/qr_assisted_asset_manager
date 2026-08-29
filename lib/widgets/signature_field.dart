import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/asset_request.dart';
import '../theme/app_theme.dart';

/// One editable "signature over printed name" block for the request form:
/// a name field plus a small preview of the uploaded/scanned signature
/// image, with buttons to take a photo of a wet-ink signature or upload an
/// existing scan/photo from the device.
///
/// Mirrors the asset-photo picker in [AddAssetForm] so uploading a
/// signature feels like the same action as uploading an asset photo.
class SignatureField extends StatefulWidget {
  const SignatureField({
    super.key,
    required this.role,
    required this.nameController,
    this.imageBytes,
    required this.onImageChanged,
    this.nameHint,
  });

  final SignatoryRole role;
  final TextEditingController nameController;

  /// The currently-picked signature image, if any.
  final Uint8List? imageBytes;

  final ValueChanged<Uint8List?> onImageChanged;
  final String? nameHint;

  @override
  State<SignatureField> createState() => _SignatureFieldState();
}

class _SignatureFieldState extends State<SignatureField> {
  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.role.label,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.nameController,
            decoration: InputDecoration(
              hintText: widget.nameHint ?? 'Printed name',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 120,
                  height: 60,
                  color: Colors.white,
                  child: imageBytes == null
                      ? const Center(
                          child: Icon(
                            Icons.draw_outlined,
                            color: AppTheme.muted,
                            size: 26,
                          ),
                        )
                      : Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}