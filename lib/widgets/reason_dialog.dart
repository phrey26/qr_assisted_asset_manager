import 'package:flutter/material.dart';

/// Prompts for a short free-text reason / remark and returns it trimmed.
///
/// Returns `null` if the admin dismissed the dialog. When [optional] is
/// false (the default) the confirm button stays disabled until something is
/// typed; when true it may return an empty string.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Save',
  bool destructive = false,
  bool optional = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final text = controller.text.trim();
          final canConfirm = optional || text.isNotEmpty;
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: hint),
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.pop(context, controller.text.trim())
                    : null,
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC84040))
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}
