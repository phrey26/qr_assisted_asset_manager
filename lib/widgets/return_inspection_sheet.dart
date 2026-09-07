import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/asset.dart';
import '../models/asset_request.dart';
import '../models/asset_return.dart';
import '../screens/camera_capture_screen.dart';
import '../theme/app_theme.dart';
import '../utils/camera_support.dart';
import '../utils/responsive.dart';

/// What the admin recorded when marking a request returned — passed to
/// `ApiService.updateRequestStatus(returnInspection: ...)`.
class ReturnInspectionInput {
  ReturnInspectionInput({
    required this.condition,
    required this.photos,
    this.notes,
    this.daysUsed,
  });

  final AssetCondition condition;
  final List<Uint8List> photos;
  final String? notes;
  final int? daysUsed;

  Map<String, dynamic> toJson() => {
        'asset_condition': condition.apiValue,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (daysUsed != null) 'days_used': daysUsed,
        'photos': [for (final p in photos) base64Encode(p)],
      };
}

/// Prompts the admin for a return inspection (condition + notes + photos)
/// before a request's assets are handed back. Returns null if they cancel.
Future<ReturnInspectionInput?> showReturnInspectionSheet(
  BuildContext context, {
  required AssetRequest request,
}) {
  if (Responsive.isDesktop(context)) {
    return showDialog<ReturnInspectionInput>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: _ReturnInspectionBody(request: request, inDialog: true),
        ),
      ),
    );
  }
  return Navigator.of(context).push<ReturnInspectionInput>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Return inspection', style: TextStyle(fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(child: _ReturnInspectionBody(request: request, inDialog: false)),
      ),
    ),
  );
}

class _ReturnInspectionBody extends StatefulWidget {
  const _ReturnInspectionBody({required this.request, required this.inDialog});

  final AssetRequest request;
  final bool inDialog;

  @override
  State<_ReturnInspectionBody> createState() => _ReturnInspectionBodyState();
}

class _ReturnInspectionBodyState extends State<_ReturnInspectionBody> {
  AssetCondition _condition = AssetCondition.good;
  final _notesController = TextEditingController();
  late final _daysController = TextEditingController(
    text: _estimatedDays()?.toString() ?? '',
  );
  final List<Uint8List> _photos = [];
  bool _busy = false;

  /// Best-effort "days out": today minus the loan's borrow date (inclusive),
  /// falling back to the stored borrow/return span.
  int? _estimatedDays() {
    final borrow = AssetItem.tryParseDate(widget.request.borrowDate);
    if (borrow == null) return null;
    final end = AssetItem.tryParseDate(widget.request.returnDate) ?? DateTime.now();
    final days = end.difference(DateTime(borrow.year, borrow.month, borrow.day)).inDays + 1;
    return days < 1 ? 1 : days;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    try {
      final images = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
      for (final image in images) {
        _photos.add(await image.readAsBytes());
      }
      if (mounted) setState(() {});
    } catch (_) {
      _toast('Could not add the selected image(s).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      if (imagePickerCameraSupported) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (image != null) _photos.add(await image.readAsBytes());
      } else {
        final bytes = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => const CameraCaptureScreen(title: 'Returned asset photo'),
          ),
        );
        if (bytes != null) _photos.add(bytes);
      }
      if (mounted) setState(() {});
    } catch (_) {
      _toast('Could not capture a photo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (_photos.isEmpty) {
      _toast('Add at least one photo of the returned item.');
      return;
    }
    final rawDays = _daysController.text.trim();
    final days = rawDays.isEmpty ? null : int.tryParse(rawDays);
    if (rawDays.isNotEmpty && (days == null || days < 0)) {
      _toast('Enter a valid number of days used.');
      return;
    }
    Navigator.pop(
      context,
      ReturnInspectionInput(
        condition: _condition,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        daysUsed: days,
        photos: List.of(_photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.request.assignedAssets;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, widget.inDialog ? 20 : 14, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.inDialog)
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Return inspection',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                Text(
                  'Record the condition of ${assets.length == 1 ? 'the asset' : 'the ${assets.length} assets'} '
                  'coming back from "${widget.request.title}", and attach photos taken now.',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 18),
                _label('Condition'),
                _conditionSelector(),
                const SizedBox(height: 18),
                _label('Days used'),
                TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 2'),
                ),
                const SizedBox(height: 18),
                _label('Notes (optional)'),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Scuffs, missing accessories, damage seen on inspection...',
                  ),
                ),
                const SizedBox(height: 18),
                _label('Photos of the returned item'),
                _photoGrid(),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Confirm return'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.darkGreen,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _conditionSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in AssetCondition.values)
          _ConditionChip(
            option: option,
            selected: option == _condition,
            onTap: () => setState(() => _condition = option),
          ),
      ],
    );
  }

  Widget _photoGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _photos[i],
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cancel, size: 22, color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (cameraCaptureSupported)
              OutlinedButton.icon(
                onPressed: _busy ? null : _capture,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Take photo'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFromGallery,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Upload photos'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AssetCondition option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = option.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? bg : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? fg : AppTheme.border,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                option.label,
                style: TextStyle(
                  color: selected ? fg : AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
