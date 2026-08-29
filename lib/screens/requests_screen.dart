import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/asset_request.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/page_header.dart';
import '../widgets/signature_field.dart';
import 'request_detail_screen.dart';

/// Pushes [RequestDetailScreen] for the given request. Mirrors
/// `_openAssetDetail` on the inventory page so tapping a request card
/// behaves the same way as tapping an asset card.
void _openRequestDetail(
  BuildContext context,
  AssetRequest request, {
  required void Function(AssetRequest request, RequestStatus status) onSetStatus,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RequestDetailScreen(
        request: request,
        onApprove: () => onSetStatus(request, RequestStatus.approved),
        onReject: () => onSetStatus(request, RequestStatus.rejected),
        onCancel: () => onSetStatus(request, RequestStatus.pending),
      ),
    ),
  );
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => RequestsScreenState();
}

/// Public so [AppShell] can reach [openNewRequest] via a [GlobalKey] and
/// trigger it from the shared circular FAB, the same way it drives
/// [InventoryScreen]'s "add asset" flow.
class RequestsScreenState extends State<RequestsScreen> {
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

  Future<void> openNewRequest() async {
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
    // Wider than the mobile/card max-width so the desktop table (which has
    // more columns than the inventory table) has room to breathe without
    // horizontal scrolling on typical desktop widths.
    final maxWidth = isDesktop ? 1120.0 : double.infinity;

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
                          onPressed: openNewRequest,
                          icon: const Icon(Icons.add),
                          label: const Text('New request'),
                          // Override the global button theme's
                          // Size.fromHeight(64), which sets an infinite
                          // minimum width intended for full-bleed buttons.
                          // Left as-is, a Row (which gives non-flex
                          // children unbounded width) can't lay this
                          // button out, which blanks the whole page.
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
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
        if (isDesktop)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _RequestsTable(
                    requests: filtered,
                    onOpen: (request) => _openRequestDetail(
                      context,
                      request,
                      onSetStatus: _setStatus,
                    ),
                    onApprove: (request) => _setStatus(request, RequestStatus.approved),
                    onReject: (request) => _setStatus(request, RequestStatus.rejected),
                    onCancel: (request) => _setStatus(request, RequestStatus.pending),
                  ),
                ),
              ),
            ),
          )
        else
          // On mobile, "New request" is triggered by the circular FAB that
          // [AppShell] shows for this tab (matching the inventory page's
          // "add asset" FAB), so no inline button is needed here — just
          // leave room at the bottom so the last card isn't hidden behind
          // the bottom nav bar and FAB.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 110),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (_, index) => Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _RequestCard(
                    request: filtered[index],
                    onTap: () => _openRequestDetail(
                      context,
                      filtered[index],
                      onSetStatus: _setStatus,
                    ),
                    onApprove: () => _setStatus(filtered[index], RequestStatus.approved),
                    onReject: () => _setStatus(filtered[index], RequestStatus.rejected),
                    onCancel: () => _setStatus(filtered[index], RequestStatus.pending),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    const filters = ['All', 'Pending', 'Approved', 'Rejected'];
    return FilterChipRow(
      options: filters,
      selected: filter,
      onSelected: (item) => setState(() => filter = item),
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

/// Desktop-only table presentation of the requests list, matching
/// [_InventoryTable] on the inventory page. Built from flexible `Row`s
/// (instead of `DataTable`, which sizes each column to its content and
/// overflows the container width) so every column — including the status
/// pill and the approve/reject/cancel actions — always fits within the
/// available width instead of being pushed off-screen behind a horizontal
/// scroll. Rows open [RequestDetailScreen] on tap; the actions stay inline
/// so admins don't have to open every row just to act on it.
class _RequestsTable extends StatelessWidget {
  const _RequestsTable({
    required this.requests,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final List<AssetRequest> requests;
  final void Function(AssetRequest request) onOpen;
  final void Function(AssetRequest request) onApprove;
  final void Function(AssetRequest request) onReject;
  final void Function(AssetRequest request) onCancel;

  // Fixed widths for the columns that hold a pill or icon buttons rather
  // than free text, so they never get squeezed. The rest of the row's
  // width is split between the flex-based text columns below.
  static const _statusWidth = 118.0;
  static const _actionsWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: const Center(
          child: Text('No requests match this filter.', style: TextStyle(color: AppTheme.muted)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerRow(),
          for (final request in requests) _dataRow(request),
        ],
      ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkGreen);
    return Container(
      color: const Color(0xFFF6F5F0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Event / purpose', style: style)),
          Expanded(flex: 2, child: Text('Requested by', style: style)),
          Expanded(flex: 2, child: Text('Department', style: style)),
          Expanded(flex: 3, child: Text('Requested items', style: style)),
          Expanded(flex: 2, child: Text('Needed', style: style)),
          SizedBox(width: _statusWidth, child: Text('Status', style: style)),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }

  Widget _dataRow(AssetRequest request) {
    const cellStyle = TextStyle(color: AppTheme.muted);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpen(request),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(request.requester, maxLines: 1, overflow: TextOverflow.ellipsis, style: cellStyle),
              ),
              Expanded(
                flex: 2,
                child: Text(request.department, maxLines: 1, overflow: TextOverflow.ellipsis, style: cellStyle),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  request.itemsSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cellStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  request.neededDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cellStyle,
                ),
              ),
              SizedBox(width: _statusWidth, child: _RequestStatusPill(status: request.status)),
              SizedBox(width: _actionsWidth, child: _tableActions(request)),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact approve/reject/cancel actions for the table row. Kept as icon
  /// buttons (rather than the full text buttons on the mobile card) so the
  /// action column stays narrow, and sized/padded down from the default
  /// [IconButton] so both icons fit inside [_actionsWidth] without wrapping.
  Widget _tableActions(AssetRequest request) {
    if (request.status == RequestStatus.pending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onApprove(request),
            icon: const Icon(Icons.check_circle_outline),
            color: AppTheme.primary,
            tooltip: 'Approve',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => onReject(request),
            icon: const Icon(Icons.cancel_outlined),
            color: Colors.redAccent,
            tooltip: 'Reject',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      );
    }
    if (request.status == RequestStatus.approved) {
      return IconButton(
        onPressed: () => onCancel(request),
        icon: const Icon(Icons.undo),
        color: AppTheme.muted,
        tooltip: 'Cancel approval',
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
    }
    return const SizedBox.shrink();
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final AssetRequest request;

  /// Invoked when the card is tapped anywhere outside the action buttons.
  /// Wired up by [RequestsScreen] to open the request's detail page, the
  /// same way [InventoryScreen] opens asset details.
  final VoidCallback? onTap;
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
      // The list wraps each card in a Center() (needed so the desktop
      // max-width cap can take effect), which hands this Container loose
      // width constraints. Without an explicit width it shrink-wraps to
      // its own text content instead of filling the space it's given,
      // so cards with shorter text end up narrower and re-centered,
      // producing a staggered left edge. Force it to fill instead.
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
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
          ),
        ),
      ),
    );
  }
}

/// The "New request" form — mirrors the office's actual borrow slip:
/// event/purpose, requester, department, an optional venue/facility, the
/// date everything is needed, and then logistics and equipment as
/// separate lists of items with amounts (e.g. "Foldable chairs" × 120).
class _NewRequestDialog extends StatefulWidget {
  const _NewRequestDialog();

  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  final titleController = TextEditingController();
  final requesterController = TextEditingController();
  final departmentController = TextEditingController();
  final venueController = TextEditingController();
  DateTime? neededDate;

  // Each list always keeps at least one (possibly blank) row so the
  // section never looks empty; blank rows are simply skipped on submit.
  final logisticsRows = [_ItemFormRow()];
  final equipmentRows = [_ItemFormRow()];

  // The four signature-over-printed-name blocks the paper slip always
  // asks for. The requester's printed name mirrors requesterController
  // so it doesn't have to be typed twice, but is kept as its own
  // controller so it can still be edited independently (e.g. someone
  // else fills out the form on the requester's behalf).
  final adviserNameController = TextEditingController();
  final principalNameController = TextEditingController();
  final deanNameController = TextEditingController();
  Uint8List? requesterSignatureBytes;
  Uint8List? adviserSignatureBytes;
  Uint8List? principalSignatureBytes;
  Uint8List? deanSignatureBytes;

  @override
  void dispose() {
    titleController.dispose();
    requesterController.dispose();
    departmentController.dispose();
    venueController.dispose();
    adviserNameController.dispose();
    principalNameController.dispose();
    deanNameController.dispose();
    for (final row in logisticsRows) {
      row.dispose();
    }
    for (final row in equipmentRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickNeededDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: neededDate ?? now,
      // Requests are for upcoming use of a venue/logistics/equipment, so
      // don't offer past dates.
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => neededDate = picked);
  }

  void _addRow(List<_ItemFormRow> rows) {
    setState(() => rows.add(_ItemFormRow()));
  }

  void _removeRow(List<_ItemFormRow> rows, int index) {
    setState(() {
      rows[index].dispose();
      rows.removeAt(index);
      // Always leave at least one row so the section has somewhere to
      // type the next item.
      if (rows.isEmpty) rows.add(_ItemFormRow());
    });
  }

  /// Turns the filled-in rows in [rows] into [RequestedItem]s, defaulting
  /// a blank amount to 1. Returns null (after showing a snackbar) if any
  /// named row has an invalid amount.
  List<RequestedItem>? _parseRows(List<_ItemFormRow> rows) {
    final items = <RequestedItem>[];
    for (final row in rows) {
      final name = row.nameController.text.trim();
      if (name.isEmpty) continue;
      final rawQuantity = row.quantityController.text.trim();
      final quantity = rawQuantity.isEmpty ? 1 : int.tryParse(rawQuantity);
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid amount for "$name".')),
        );
        return null;
      }
      items.add(RequestedItem(name: name, quantity: quantity));
    }
    return items;
  }

  void _submit() {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the event / purpose.')),
      );
      return;
    }
    if (neededDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select the date it's needed.")),
      );
      return;
    }

    final logistics = _parseRows(logisticsRows);
    if (logistics == null) return;
    final equipment = _parseRows(equipmentRows);
    if (equipment == null) return;
    final venue = venueController.text.trim();

    if (venue.isEmpty && logistics.isEmpty && equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a venue, logistics, or equipment for this request.'),
        ),
      );
      return;
    }

    final requesterName =
        requesterController.text.trim().isEmpty ? 'You' : requesterController.text.trim();

    Navigator.pop(
      context,
      AssetRequest(
        title: titleController.text.trim(),
        requester: requesterName,
        department:
            departmentController.text.trim().isEmpty ? 'CSDO' : departmentController.text.trim(),
        venue: venue.isEmpty ? null : venue,
        logistics: logistics,
        equipment: equipment,
        neededDate: AssetItem.formatDate(neededDate!),
        requesterSignature: Signatory(
          name: requesterName,
          imageBytes: requesterSignatureBytes,
        ),
        adviserSignature: Signatory(
          name: adviserNameController.text.trim(),
          imageBytes: adviserSignatureBytes,
        ),
        principalSignature: Signatory(
          name: principalNameController.text.trim(),
          imageBytes: principalSignatureBytes,
        ),
        deanSignature: Signatory(
          name: deanNameController.text.trim(),
          imageBytes: deanSignatureBytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _field('Event / purpose', titleController, hint: 'e.g. Freshmen orientation'),
                      _field('Requested by', requesterController, hint: 'Your name'),
                      _field('Department / org', departmentController, hint: 'e.g. OSA'),
                      _field(
                        'Venue / facility',
                        venueController,
                        hint: 'e.g. Gymnasium — leave blank if none needed',
                      ),
                      _dateField(),
                      const SizedBox(height: 6),
                      _itemsSection(
                        'Logistics',
                        logisticsRows,
                        hint: 'e.g. Foldable chairs',
                      ),
                      const SizedBox(height: 10),
                      _itemsSection(
                        'Equipment',
                        equipmentRows,
                        hint: 'e.g. Wireless microphone',
                      ),
                      const SizedBox(height: 10),
                      _signaturesSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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

  /// Date picker field for "when it's needed", styled to match
  /// [AddAssetForm]'s "Date of purchase" field.
  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date needed',
            style: TextStyle(color: AppTheme.darkGreen, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickNeededDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                neededDate == null ? 'Select date' : AssetItem.formatDate(neededDate!),
                style: TextStyle(
                  color: neededDate == null ? AppTheme.muted : AppTheme.darkGreen,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A labeled group of item-name + amount rows (used for both Logistics
  /// and Equipment), with an "Add item" action to append another row.
  Widget _itemsSection(String label, List<_ItemFormRow> rows, {required String hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.darkGreen, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) _itemRow(rows, i, hint: hint),
          TextButton.icon(
            onPressed: () => _addRow(rows),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add ${label.toLowerCase()} item'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  /// The "Signatures" section: one upload block per role on the paper
  /// slip — requester, adviser, principal/office head, and dean — each
  /// with a printed-name field and a scanned/photographed signature
  /// image in lieu of a wet-ink signature.
  Widget _signaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signatures',
          style: TextStyle(color: AppTheme.darkGreen, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Upload a scanned or photographed signature for each approver, over their printed name — same as the paper form.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        SignatureField(
          role: SignatoryRole.requester,
          nameController: requesterController,
          nameHint: 'Your name',
          imageBytes: requesterSignatureBytes,
          onImageChanged: (bytes) => setState(() => requesterSignatureBytes = bytes),
        ),
        SignatureField(
          role: SignatoryRole.adviser,
          nameController: adviserNameController,
          imageBytes: adviserSignatureBytes,
          onImageChanged: (bytes) => setState(() => adviserSignatureBytes = bytes),
        ),
        SignatureField(
          role: SignatoryRole.principal,
          nameController: principalNameController,
          imageBytes: principalSignatureBytes,
          onImageChanged: (bytes) => setState(() => principalSignatureBytes = bytes),
        ),
        SignatureField(
          role: SignatoryRole.dean,
          nameController: deanNameController,
          imageBytes: deanSignatureBytes,
          onImageChanged: (bytes) => setState(() => deanSignatureBytes = bytes),
        ),
      ],
    );
  }

  Widget _itemRow(List<_ItemFormRow> rows, int index, {required String hint}) {
    final row = rows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.nameController,
              decoration: InputDecoration(hintText: hint),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: row.quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: 'Qty'),
            ),
          ),
          SizedBox(
            width: 40,
            child: rows.length > 1
                ? IconButton(
                    onPressed: () => _removeRow(rows, index),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove item',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Holds the two controllers for one logistics/equipment row (item name +
/// amount) in [_NewRequestDialog].
class _ItemFormRow {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}