import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/status_badge.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCsdoAppBar(
        leadingIcon: Icons.description_outlined,
        title: 'Asset request',
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'New request'),
                Tab(text: 'My requests'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _NewRequestTab(),
                _MyRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRequestTab extends StatelessWidget {
  const _NewRequestTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: 'Request form'),
              const SizedBox(height: 16),
              const _FieldLabel('Requested by'),
              const SizedBox(height: 6),
              TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'Staff name (auto-filled)',
                  fillColor: AppColors.surfaceAlt.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Department / Office'),
              const SizedBox(height: 6),
              const _DropdownField(hint: 'Select department...'),
              const SizedBox(height: 16),
              const _FieldLabel('Asset / Equipment needed'),
              const SizedBox(height: 6),
              const TextField(
                decoration:
                    InputDecoration(hintText: 'Search or select asset...'),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Quantity'),
                        const SizedBox(height: 6),
                        TextField(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: '1'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Date needed'),
                        const SizedBox(height: 6),
                        const TextField(
                          decoration:
                              InputDecoration(hintText: 'mm/dd/yyyy'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Purpose / Justification'),
              const SizedBox(height: 6),
              const TextField(
                maxLines: 4,
                decoration: InputDecoration(hintText: 'Describe the purpose...'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Submit request'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Policy reminders ----
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SectionHeading(title: 'Policy reminders'),
              SizedBox(height: 12),
              InfoBullet(text: 'Requests must be submitted at least 1 day in advance.'),
              InfoBullet(text: 'Maximum of 3 equipment requests per week per staff.'),
              InfoBullet(text: 'All requests require department head approval.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyRequestsTab extends StatelessWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(title: 'My recent requests'),
              const SizedBox(height: 14),
              const _MyRequestRow(name: 'Projector #3', label: 'Pending', tone: BadgeTone.orange),
              const Divider(height: 24),
              const _MyRequestRow(name: 'Laptop #7', label: 'Approved', tone: BadgeTone.green),
              const Divider(height: 24),
              const _MyRequestRow(name: 'Printer #1', label: 'Rejected', tone: BadgeTone.red),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyRequestRow extends StatelessWidget {
  final String name;
  final String label;
  final BadgeTone tone;

  const _MyRequestRow({required this.name, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        StatusBadge(label: label, tone: tone),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String hint;
  const _DropdownField({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
