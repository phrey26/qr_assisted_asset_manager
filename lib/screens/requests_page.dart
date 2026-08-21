import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/card_container.dart';
import '../widgets/section_title.dart';
import '../widgets/status_badge.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  String? department;
  String? asset;

  final quantityController =
      TextEditingController(text: '1');

  final purposeController =
      TextEditingController();

  @override
  void dispose() {
    quantityController.dispose();
    purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          const AppHeader(
            title: 'Asset request',
            subtitle: 'Submit an equipment request',
          ),

          // ============================================================
          // REQUEST FORM
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request form',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ----------------------------------------------------
                  // REQUESTED BY
                  // ----------------------------------------------------
                  const FormFieldLabel(
                    'Requested by',
                  ),

                  const TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Staff name (auto-filled)',
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ----------------------------------------------------
                  // DEPARTMENT / OFFICE
                  // ----------------------------------------------------
                  const FormFieldLabel(
                    'Department / Office',
                  ),

                  SelectField(
                    value: department,
                    hint: 'Select department...',
                    onTap: () {
                      _select(
                        'Select department',
                        [
                          'Information Technology',
                          'Office of Student Affairs',
                          'Academic Affairs',
                          'Administration',
                          'Campus Services and Development Office',
                        ],
                        (value) {
                          setState(() {
                            department = value;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // ----------------------------------------------------
                  // ASSET / EQUIPMENT
                  // ----------------------------------------------------
                  const FormFieldLabel(
                    'Asset / Equipment needed',
                  ),

                  SelectField(
                    value: asset,
                    hint: 'Search or select asset...',
                    onTap: () {
                      _select(
                        'Select asset',
                        [
                          'Projector #3',
                          'Laptop #7',
                          'Printer #1',
                          'Whiteboard marker',
                          'Extension cord',
                        ],
                        (value) {
                          setState(() {
                            asset = value;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // ----------------------------------------------------
                  // QUANTITY + DATE
                  // ----------------------------------------------------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const FormFieldLabel(
                              'Quantity',
                            ),

                            TextField(
                              controller:
                                  quantityController,
                              keyboardType:
                                  TextInputType.number,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const FormFieldLabel(
                              'Date needed',
                            ),

                            TextField(
                              readOnly: true,
                              decoration:
                                  const InputDecoration(
                                hintText: 'mm/dd/yyyy',
                                suffixIcon: Icon(
                                  Icons
                                      .calendar_today_outlined,
                                  size: 18,
                                ),
                              ),
                              onTap: () {
                                _selectDate(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ----------------------------------------------------
                  // PURPOSE / JUSTIFICATION
                  // ----------------------------------------------------
                  const FormFieldLabel(
                    'Purpose / Justification',
                  ),

                  TextField(
                    controller: purposeController,
                    minLines: 4,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe the purpose...',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ----------------------------------------------------
                  // SUBMIT BUTTON
                  // ----------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Request preview submitted. Backend will be added later.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.send_outlined,
                      ),
                      label: const Text(
                        'Submit request',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ============================================================
          // POLICY REMINDERS
          // ============================================================
          const SectionTitle(
            title: 'Policy reminders',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  PolicyItem(
                    text:
                        'Requests must be submitted at least 1 day in advance.',
                  ),
                  PolicyItem(
                    text:
                        'Maximum of 3 equipment requests per staff per week.',
                  ),
                  PolicyItem(
                    text:
                        'All requests require department head approval.',
                  ),
                ],
              ),
            ),
          ),

          // ============================================================
          // RECENT REQUESTS
          // ============================================================
          const SectionTitle(
            title: 'My recent requests',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CardContainer(
              child: Column(
                children: [
                  RecentRequest(
                    name: 'Projector #3',
                    status: 'Pending',
                  ),
                  RecentRequest(
                    name: 'Laptop #7',
                    status: 'Approved',
                  ),
                  RecentRequest(
                    name: 'Printer #1',
                    status: 'Rejected',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // SELECT BOTTOM SHEET
  // ==================================================================

  void _select(
    String title,
    List<String> options,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                ...options.map(
                  (option) {
                    return ListTile(
                      title: Text(option),
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================================================================
  // DATE PICKER
  // ==================================================================

  Future<void> _selectDate(
    BuildContext context,
  ) async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      initialDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    // Front-end only for now.
    // The selected date can later be stored
    // in a model/database.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected date: '
          '${selectedDate.month}/'
          '${selectedDate.day}/'
          '${selectedDate.year}',
        ),
      ),
    );
  }
}

// ======================================================================
// FORM FIELD LABEL
// ======================================================================

class FormFieldLabel extends StatelessWidget {
  final String text;

  const FormFieldLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ======================================================================
// SELECT FIELD
// ======================================================================

class SelectField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;

  const SelectField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null &&
        value!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value! : hint,
                style: TextStyle(
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),

            const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// POLICY ITEM
// ======================================================================

class PolicyItem extends StatelessWidget {
  final String text;

  const PolicyItem({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 17,
            color: Color(0xFF3D8EC9),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// RECENT REQUEST
// ======================================================================

class RecentRequest extends StatelessWidget {
  final String name;
  final String status;

  const RecentRequest({
    super.key,
    required this.name,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          StatusBadge(
            label: status,
          ),
        ],
      ),
    );
  }
}