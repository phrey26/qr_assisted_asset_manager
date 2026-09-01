import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';

/// Shows the "add new category" dialog, letting the admin name a new
/// category and pick an icon/color for its card. Returns the new
/// [AssetCategory], or null if the admin cancels.
///
/// [existingNames] is used to reject duplicates (case-insensitively) so a
/// new category can never collide with one that already exists — that
/// would make assets impossible to tell apart by filter/dropdown.
Future<AssetCategory?> showAddCategoryDialog(
  BuildContext context, {
  required List<String> existingNames,
}) {
  return showDialog<AssetCategory>(
    context: context,
    builder: (_) => _AddCategoryDialog(existingNames: existingNames),
  );
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({required this.existingNames});

  final List<String> existingNames;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final controller = TextEditingController();
  IconData icon = AssetCategory.iconChoices.first;
  Color color = AssetCategory.colorChoices.first;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = controller.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Please enter a category name.');
      return;
    }
    final duplicate = widget.existingNames.any(
      (existing) => existing.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      setState(() => error = 'A category with this name already exists.');
      return;
    }
    Navigator.pop(
      context,
      AssetCategory(displayName: name, value: name, icon: icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Add new category',
        style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Kitchen appliances',
                errorText: error,
              ),
              onChanged: (_) {
                if (error != null) setState(() => error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 22),
            const Text(
              'Icon',
              style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w700, fontSize: 15),
            ),
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
            const SizedBox(height: 22),
            const Text(
              'Color',
              style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w700, fontSize: 15),
            ),
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
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.darkGreen,
            side: const BorderSide(color: AppTheme.border, width: 2),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Add category'),
        ),
      ],
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
  const _ColorChoice({required this.color, required this.selected, required this.onTap});

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