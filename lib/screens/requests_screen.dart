import 'package:flutter/material.dart';

import '../models/asset_request.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/page_header.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final List<AssetRequest> requests = AssetRequest.samples;
  String filter = 'All';

  List<AssetRequest> get filtered {
    if (filter == 'All') return requests;
    return requests.where((r) => r.status.label == filter).toList();
  }

  int get pendingCount =>
      requests.where((r) => r.status == RequestStatus.pending).length;

  void _setStatus(AssetRequest request, RequestStatus status) {
    setState(() => request.status = status);
  }

  Future<void> _openNewRequest() async {
    final created = await showDialog<AssetRequest>(
      context: context,
      builder: (_) => const _NewRequestDialog(),
    );
    if (created != null) {
      setState(() => requests.insert(0, created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 960.0 : double.infinity;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 0),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PageHeader(
                        title: 'Requests',
                        subtitle: '$pendingCount pending approval',
                        showMark: false,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ElevatedButton.icon(
                          onPressed: _openNewRequest,
                          icon: const Icon(Icons.add),
                          label: const Text('New request'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _filters(),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(28, 0, 28, isDesktop ? 40 : 110),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _RequestCard(
                  request: filtered[index],
                  onApprove: () => _setStatus(filtered[index], RequestStatus.approved),
                  onReject: () => _setStatus(filtered[index], RequestStatus.rejected),
                  onCancel: () => _setStatus(filtered[index], RequestStatus.pending),
                ),
              ),
            ),
          ),
        ),
        if (!isDesktop)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 110),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openNewRequest,
                  icon: const Icon(Icons.add),
                  label: const Text('New request'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    const filters = ['All', 'Pending', 'Approved', 'Rejected'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = filter == item;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => setState(() => filter = item),
              selectedColor: AppTheme.darkGreen,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.border, width: 2),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RequestStatusPill extends StatelessWidget {
  const _RequestStatusPill({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    switch (status) {
      case RequestStatus.pending:
        background = AppTheme.cream;
        foreground = const Color(0xFF9A6512);
      case RequestStatus.approved:
        background = AppTheme.mint;
        foreground = AppTheme.primary;
      case RequestStatus.rejected:
        background = AppTheme.redTint;
        foreground = const Color(0xFFC84040);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final AssetRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          request.title,
          style: const TextStyle(
            color: AppTheme.darkGreen,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          request.detailLine,
          style: const TextStyle(color: AppTheme.muted, fontSize: 15),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _RequestStatusPill(status: request.status),
        if (request.status == RequestStatus.pending) ...[
          FilledButton(onPressed: onApprove, child: const Text('Approve')),
          OutlinedButton(onPressed: onReject, child: const Text('Reject')),
        ] else if (request.status == RequestStatus.approved)
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 16), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _NewRequestDialog extends StatefulWidget {
  const _NewRequestDialog();

  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  final titleController = TextEditingController();
  final requesterController = TextEditingController();
  final departmentController = TextEditingController();
  final itemController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    requesterController.dispose();
    departmentController.dispose();
    itemController.dispose();
    super.dispose();
  }

  void _submit() {
    if (titleController.text.trim().isEmpty || itemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the event and item requested.')),
      );
      return;
    }
    Navigator.pop(
      context,
      AssetRequest(
        title: titleController.text.trim(),
        requester: requesterController.text.trim().isEmpty
            ? 'You'
            : requesterController.text.trim(),
        department: departmentController.text.trim().isEmpty
            ? 'CSDO'
            : departmentController.text.trim(),
        itemDescription: itemController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New request',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _field('Event / purpose', titleController, hint: 'e.g. Freshmen orientation'),
              _field('Requested by', requesterController, hint: 'Your name'),
              _field('Department / org', departmentController, hint: 'e.g. OSA'),
              _field('Item requested', itemController, hint: 'e.g. Wireless microphone'),
              const SizedBox(height: 10),
              Row(
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
                      onPressed: _submit,
                      child: const Text('Submit request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
