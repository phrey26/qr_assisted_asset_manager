import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// The "add category" form fields, shared between [AddCategoryDialog] (the
/// centered desktop modal) and [AddCategoryScreen] (the full-page mobile
/// flow) so the two entry points can never drift apart — the same split and
/// reasoning as [AddAssetForm].
class AddCategoryForm extends StatefulWidget {
  const AddCategoryForm({
    super.key,
    required this.existingNames,
    required this.onSubmit,
    this.onCancel,
    this.compact = false,
  });

  /// Existing category names, used to reject a duplicate (case-insensitively)
  /// so a new category can never collide with one that already exists.
  final List<String> existingNames;

  final ValueChanged<AssetCategory> onSubmit;

  /// Shown as a "Cancel" button beside the save button when provided
  /// (desktop dialog). Null on the mobile full page, which has a back arrow.
  final VoidCallback? onCancel;

  /// Tightens vertical spacing for use inside the modal dialog.
  final bool compact;

  @override
  State<AddCategoryForm> createState() => _AddCategoryFormState();
}

class _AddCategoryFormState extends State<AddCategoryForm> {
  final nameController = TextEditingController();
  final lifespanController = TextEditingController();
  IconData icon = AssetCategory.iconChoices.first;
  Color color = AssetCategory.colorChoices.first;
  AssetTracking tracking = AssetTracking.individual;
  String? nameError;
  String? lifespanError;

  @override
  void dispose() {
    nameController.dispose();
    lifespanController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => nameError = 'Please enter a category name.');
      return;
    }
    final duplicate = widget.existingNames.any(
      (existing) => existing.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      setState(() => nameError = 'A category with this name already exists.');
      return;
    }
    // Optional, and only meaningful for individually-tracked assets: a bulk
    // pool is one row with one purchase date (restocks don't move it), so
    // it's never age-flagged. The field is hidden when the default is bulk;
    // ignore anything left in it. Blank otherwise means "don't age-flag".
    int? lifespanYears;
    if (tracking != AssetTracking.bulk) {
      final rawLifespan = lifespanController.text.trim();
      if (rawLifespan.isNotEmpty) {
        final parsed = int.tryParse(rawLifespan);
        if (parsed == null || parsed <= 0) {
          setState(
            () => lifespanError =
                'Enter a whole number of years, or leave it blank.',
          );
          return;
        }
        lifespanYears = parsed;
      }
    }
    widget.onSubmit(
      AssetCategory(
        displayName: name,
        value: name,
        icon: icon,
        color: color,
        defaultTracking: tracking,
        lifespanYears: lifespanYears,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.compact ? 20.0 : 26.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Category name'),
        const SizedBox(height: 10),
        TextField(
          controller: nameController,
          autofocus: widget.compact,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Kitchen appliances',
            errorText: nameError,
          ),
          onChanged: (_) {
            if (nameError != null) setState(() => nameError = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: gap),
        _label('Icon'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final choice in AssetCategory.iconChoices)
              _IconChoice(
                icon: choice,
                selected: choice == icon,
                badgeColor: color,
                onTap: () => setState(() => icon = choice),
              ),
          ],
        ),
        SizedBox(height: gap),
        _label('Color'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final choice in AssetCategory.colorChoices)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _ColorChoice(
                  color: choice,
                  selected: choice == color,
                  onTap: () => setState(() => color = choice),
                ),
              ),
          ],
        ),
        SizedBox(height: gap),
        _label('Assets in this category are usually'),
        const SizedBox(height: 10),
        for (final option in AssetTracking.values)
          _TrackingChoice(
            option: option,
            selected: option == tracking,
            onTap: () => setState(() {
              tracking = option;
              // The lifespan field is hidden for bulk — drop any error it
              // was showing so it doesn't flash back on a later switch.
              if (option == AssetTracking.bulk) lifespanError = null;
            }),
          ),
        const SizedBox(height: 4),
        const Text(
          'Just the default when adding an asset — you can switch it per asset.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.35),
        ),
        // Only for individually-tracked assets. A bulk pool carries a count,
        // not dated units, so it can't be age-flagged — hide the field when
        // that's the default (a mostly-individual category still shows it,
        // with the note below explaining bulk assets in it are exempt).
        if (tracking != AssetTracking.bulk) ...[
          SizedBox(height: gap),
          _label('Expected lifespan'),
          const SizedBox(height: 10),
          TextField(
            controller: lifespanController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g. 5',
              suffixText: 'years',
              errorText: lifespanError,
            ),
            onChanged: (_) {
              if (lifespanError != null) setState(() => lifespanError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),
          const Text(
            'Applies to individually-tracked assets only — bulk pools aren\'t '
            'flagged by age. Leave blank for things that don\'t age out '
            '(e.g. furniture).',
            style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.35),
          ),
        ],
        SizedBox(height: widget.compact ? 22 : 34),
        _saveRow(),
      ],
    );
  }

  Widget _label(String value) => Text(
    value,
    style: const TextStyle(
      color: AppTheme.darkGreen,
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
  );

  Widget _saveRow() {
    final addButton = ElevatedButton(
      onPressed: _submit,
      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
      child: const Text('Add category'),
    );
    if (widget.onCancel == null) {
      return SizedBox(width: double.infinity, child: addButton);
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.darkGreen,
              side: const BorderSide(color: AppTheme.border, width: 2),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: addButton),
      ],
    );
  }
}

class _TrackingChoice extends StatelessWidget {
  const _TrackingChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AssetTracking option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = option == AssetTracking.bulk
        ? 'Counted as a quantity (cables, markers, chairs…)'
        : 'Each unit tagged and tracked on its own';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.mint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                option == AssetTracking.bulk
                    ? Icons.inventory_2_outlined
                    : Icons.qr_code_2,
                size: 20,
                color: selected ? AppTheme.primary : AppTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: selected ? AppTheme.primary : AppTheme.darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppTheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.badgeColor,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? badgeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: 2,
          ),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 3 : 2,
          ),
        ),
      ),
    );
  }
}
