import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/asset_request.dart';
import '../models/asset_return.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_assignment_sheet.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/page_header.dart';
import '../widgets/request_date_range_field.dart';
import '../widgets/request_form_field.dart';
import '../widgets/return_inspection_sheet.dart';
import 'request_detail_screen.dart';

/// Pushes [RequestDetailScreen] for the given request. Mirrors
/// `_openAssetDetail` on the inventory page so tapping a request card
/// behaves the same way as tapping an asset card.
///
/// [onApprove] opens the asset picker and, once assets are chosen, approves
/// the request; [onSetStatus] handles the reject/cancel transitions (which
/// take no assets and just release whatever the request was holding).
void _openRequestDetail(
  BuildContext context,
  AssetRequest request, {
  required Future<void> Function(AssetRequest request) onApprove,
  required Future<void> Function(AssetRequest request) onMarkReturned,
  required void Function(AssetRequest request, RequestStatus status) onSetStatus,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RequestDetailScreen(
        request: request,
        onApprove: () => onApprove(request),
        onMarkReturned: () => onMarkReturned(request),
        onReject: () => onSetStatus(request, RequestStatus.rejected),
        onCancel: () => onSetStatus(request, RequestStatus.pending),
      ),
    ),
  );
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    this.currentUser,
    required this.assets,
    required this.onApplyAssetStatuses,
    required this.onApplyAssetCondition,
    required this.onApplyBulkOut,
  });

  /// The signed-in user's row from `user` (as returned by
  /// `csdo_api/login.php`) — used to prefill "Requested by"/"Department" on
  /// [NewRequestForm]. Null falls back to the form's own blank defaults.
  final Map<String, dynamic>? currentUser;

  /// The live inventory list, owned by `AppShell`. Shown in the asset
  /// picker when approving a request; the same mutable [AssetItem] objects
  /// the Inventory tab renders, so status changes made here show up there.
  final List<AssetItem> assets;

  /// Mirrors an asset status change (already persisted by the backend
  /// during a request status update) into `AppShell`'s inventory list, so
  /// the Inventory tab stays in sync without a reload.
  final void Function(Iterable<String> tagIds, AssetStatus status) onApplyAssetStatuses;

  /// Mirrors the condition recorded in a return inspection onto the local
  /// inventory (`condition` slug: 'good' | 'fair' | 'poor' | 'damaged', or
  /// null to clear), so the "Damaged" badge appears on the asset list right
  /// after a return.
  final void Function(Iterable<String> tagIds, String? condition) onApplyAssetCondition;

  /// Mirrors a change to bulk pools' units-on-loan into the local inventory.
  /// Keys are tag IDs, values are signed deltas to `quantityOut` (+ when a
  /// pool is lent from on approval, − when units come back on return/cancel).
  /// [damagedDeltas], when given, additionally adjusts `quantityDamaged` —
  /// units reported damaged on return are set aside (not written off), so
  /// the pool's owned total is untouched.
  final void Function(Map<String, int> outDeltas, {Map<String, int>? damagedDeltas})
      onApplyBulkOut;

  @override
  State<RequestsScreen> createState() => RequestsScreenState();
}

/// Public so [AppShell] can reach [openNewRequest] via a [GlobalKey] and
/// trigger it from the shared circular FAB, the same way it drives
/// [InventoryScreen]'s "add asset" flow.
class RequestsScreenState extends State<RequestsScreen> {
  List<AssetRequest> requests = [];
  String filter = 'All';
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Deferred to the next frame for the same reason [AppShell] does this
    // in main.dart: _loadRequests calls setState before its first `await`,
    // and calling that synchronously from initState (itself invoked while
    // the parent is still building) throws "setState() or markNeedsBuild()
    // called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rows = await ApiService.fetchRequests();
      if (!mounted) return;
      setState(() {
        requests = rows.map(AssetRequest.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load requests from the server: $e';
        _loading = false;
      });
    }
  }

  List<AssetRequest> get filtered {
    if (filter == 'All') return requests;
    return requests.where((r) => r.status.label == filter).toList();
  }

  int get pendingCount =>
      requests.where((r) => r.status == RequestStatus.pending).length;

  /// Applies [status] locally right away, then syncs it to the backend;
  /// reverted (with an error snackbar) if that call fails.
  ///
  /// Only handles the transitions that carry no asset assignment —
  /// rejecting a pending request, or cancelling an approval. Both release
  /// whatever assets the request was holding (back to `available`);
  /// approving goes through [_approveRequest] instead, since it has to
  /// collect the assets first.
  Future<void> _setStatus(AssetRequest request, RequestStatus status) async {
    final previousStatus = request.status;
    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);
    final wasApproved = previousStatus == RequestStatus.approved;
    final freedIndividual =
        previousAssigned.where((a) => !a.isBulk).map((a) => a.tagId).toList();
    final bulkRestore = {
      for (final a in previousAssigned)
        if (a.isBulk) a.tagId: -a.quantity,
    };

    setState(() {
      request.status = status;
      request.assignedAssets = const [];
    });
    if (wasApproved && freedIndividual.isNotEmpty) {
      widget.onApplyAssetStatuses(freedIndividual, AssetStatus.available);
    }
    if (wasApproved && bulkRestore.isNotEmpty) widget.onApplyBulkOut(bulkRestore);
    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(id: request.id!, status: status.apiValue);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.assignedAssets = previousAssigned;
      });
      if (wasApproved && freedIndividual.isNotEmpty) {
        widget.onApplyAssetStatuses(freedIndividual, AssetStatus.inUse);
      }
      if (wasApproved && bulkRestore.isNotEmpty) {
        widget.onApplyBulkOut({for (final e in bulkRestore.entries) e.key: -e.value});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update the request\'s status: $e')),
      );
    }
  }

  /// Approve flow: the admin must pick the assets to hand out before the
  /// request can be approved. On confirm, those assets are marked `inUse`
  /// (locally and on the backend, in one transaction); any assets that
  /// were assigned before but dropped from the new selection are freed.
  Future<void> _approveRequest(AssetRequest request) async {
    final wasApproved = request.status == RequestStatus.approved;
    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);
    final previousIndividualTags = previousAssigned
        .where((a) => !a.isBulk)
        .map((a) => a.tagId)
        .toList();
    final previousBulkQty = {
      for (final a in previousAssigned)
        if (a.isBulk) a.tagId: a.quantity,
    };

    final picked = await showAssetAssignmentPicker(
      context,
      assets: widget.assets,
      request: request,
      preselectedTagIds: previousIndividualTags,
      preselectedQuantities: previousBulkQty,
    );
    if (!mounted || picked == null || picked.isEmpty) return;

    final previousStatus = request.status;

    final newIndividualTags =
        picked.where((p) => !p.asset.isBulk).map((p) => p.asset.tagId).toList();
    final newBulkQty = {
      for (final p in picked)
        if (p.asset.isBulk) p.asset.tagId: p.quantity,
    };

    // Individual assets dropped from the selection since last time → free.
    final freedIndividual =
        previousIndividualTags.toSet().difference(newIndividualTags.toSet());
    // Net bulk delta = (new take) − (old take) per pool.
    final bulkDeltas = <String, int>{};
    for (final tag in {...previousBulkQty.keys, ...newBulkQty.keys}) {
      final delta = (newBulkQty[tag] ?? 0) - (previousBulkQty[tag] ?? 0);
      if (delta != 0) bulkDeltas[tag] = delta;
    }

    setState(() {
      request.status = RequestStatus.approved;
      request.assignedAssets = picked
          .map((p) => AssignedAsset.fromAsset(p.asset, quantity: p.quantity))
          .toList();
    });
    if (freedIndividual.isNotEmpty) {
      widget.onApplyAssetStatuses(freedIndividual, AssetStatus.available);
    }
    if (newIndividualTags.isNotEmpty) {
      widget.onApplyAssetStatuses(newIndividualTags, AssetStatus.inUse);
    }
    if (bulkDeltas.isNotEmpty) widget.onApplyBulkOut(bulkDeltas);

    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(
        id: request.id!,
        status: RequestStatus.approved.apiValue,
        assignments: picked.map((p) => p.toBody()).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.assignedAssets = previousAssigned;
      });
      // Undo the optimistic inventory changes.
      if (newIndividualTags.isNotEmpty) {
        widget.onApplyAssetStatuses(newIndividualTags, AssetStatus.available);
      }
      if (previousIndividualTags.isNotEmpty && wasApproved) {
        widget.onApplyAssetStatuses(previousIndividualTags, AssetStatus.inUse);
      }
      if (bulkDeltas.isNotEmpty) {
        widget.onApplyBulkOut({for (final e in bulkDeltas.entries) e.key: -e.value});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve the request: $e')),
      );
    }
  }

  /// Return flow: the borrowed assets have come back. First collects a
  /// return inspection (condition + notes + photos taken now), then frees
  /// every assigned asset to `available` again and moves the request to the
  /// terminal [RequestStatus.returned] state — the assignment record is
  /// kept so the request still shows what was lent, and the inspection is
  /// recorded against each asset's condition & usage history.
  Future<void> _markReturned(AssetRequest request) async {
    final inspection = await showReturnInspectionSheet(context, request: request);
    if (!mounted || inspection == null) return;

    final previousStatus = request.status;
    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);
    final individualTags =
        previousAssigned.where((a) => !a.isBulk).map((a) => a.tagId).toList();
    final bulkLines = previousAssigned.where((a) => a.isBulk).toList();

    // Bulk pools: every lent unit comes back (quantityOut -= lent); any
    // reported damaged is then SET ASIDE (quantityDamaged += dmg), not
    // written off — the owned total is untouched.
    final bulkOutRestore = {for (final a in bulkLines) a.tagId: -a.quantity};
    final bulkDamagedGain = <String, int>{};
    for (final a in bulkLines) {
      final dmg = (inspection.bulkDamaged[a.tagId] ?? 0).clamp(0, a.quantity);
      if (dmg > 0) bulkDamagedGain[a.tagId] = dmg;
    }

    // Snapshot each individual asset's recorded condition so an optimistic
    // "damaged" badge can be rolled back if the return call fails.
    final previousConditions = {
      for (final a in widget.assets)
        if (individualTags.contains(a.tagId)) a.tagId: a.lastConditionRaw,
    };

    setState(() {
      request.status = RequestStatus.returned;
      request.assignedAssets = previousAssigned
          .map((a) => AssignedAsset(
                tagId: a.tagId,
                name: a.name,
                category: a.category,
                status: AssetStatus.available,
                tracking: a.tracking,
                quantity: a.quantity,
              ))
          .toList();
    });
    if (individualTags.isNotEmpty) {
      widget.onApplyAssetStatuses(individualTags, AssetStatus.available);
      widget.onApplyAssetCondition(individualTags, inspection.condition.apiValue);
    }
    if (bulkOutRestore.isNotEmpty) {
      widget.onApplyBulkOut(
        bulkOutRestore,
        damagedDeltas: bulkDamagedGain.isEmpty ? null : bulkDamagedGain,
      );
    }
    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(
        id: request.id!,
        status: RequestStatus.returned.apiValue,
        returnInspection: inspection.toJson(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.assignedAssets = previousAssigned;
      });
      if (individualTags.isNotEmpty) {
        widget.onApplyAssetStatuses(individualTags, AssetStatus.inUse);
        for (final entry in previousConditions.entries) {
          widget.onApplyAssetCondition([entry.key], entry.value);
        }
      }
      if (bulkOutRestore.isNotEmpty) {
        widget.onApplyBulkOut(
          {for (final e in bulkOutRestore.entries) e.key: -e.value},
          damagedDeltas: bulkDamagedGain.isEmpty
              ? null
              : {for (final e in bulkDamagedGain.entries) e.key: -e.value},
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark the request as returned: $e')),
      );
    }
  }

  Future<void> openNewRequest() async {
    final user = widget.currentUser;
    final AssetRequest? created;
    if (Responsive.isMobile(context)) {
      created = await Navigator.of(context).push<AssetRequest>(
        MaterialPageRoute(
          builder: (_) => NewRequestForm(
            fullPage: true,
            initialRequester: user?['full_name'] as String?,
            initialDepartment: user?['department'] as String?,
          ),
        ),
      );
    } else {
      created = await showDialog<AssetRequest>(
        context: context,
        builder: (_) => NewRequestForm(
          initialRequester: user?['full_name'] as String?,
          initialDepartment: user?['department'] as String?,
        ),
      );
    }
    if (created == null) return;

    try {
      final id = await ApiService.addRequest(created.toJson());
      if (!mounted) return;
      setState(() => requests.insert(0, AssetRequest.fromJson({...created!.toJson(), 'id': id})));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit the request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    // Wider than the mobile/card max-width so the desktop table (which has
    // more columns than the inventory table) has room to breathe without
    // horizontal scrolling on typical desktop widths.
    final maxWidth = isDesktop ? 1120.0 : double.infinity;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _loadRequests, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

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
                      onApprove: _approveRequest,
                      onMarkReturned: _markReturned,
                      onSetStatus: _setStatus,
                    ),
                    onApprove: (request) => _openRequestDetail(
                      context,
                      request,
                      onApprove: _approveRequest,
                      onMarkReturned: _markReturned,
                      onSetStatus: _setStatus,
                    ),
                    onReject: (request) => _openRequestDetail(
                      context,
                      request,
                      onApprove: _approveRequest,
                      onMarkReturned: _markReturned,
                      onSetStatus: _setStatus,
                    ),
                    onCancel: (request) => _setStatus(request, RequestStatus.pending),
                    onReturn: (request) => _openRequestDetail(
                      context,
                      request,
                      onApprove: _approveRequest,
                      onMarkReturned: _markReturned,
                      onSetStatus: _setStatus,
                    ),
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
            padding: EdgeInsets.fromLTRB(28, 0, 28, Responsive.bottomScrollClearance(context)),
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
                      onApprove: _approveRequest,
                      onMarkReturned: _markReturned,
                      onSetStatus: _setStatus,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    const filters = ['All', 'Pending', 'Approved', 'Returned', 'Rejected'];
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
      case RequestStatus.returned:
        background = AppTheme.slateTint;
        foreground = AppTheme.muted;
      case RequestStatus.rejected:
        background = AppTheme.redTint;
        foreground = const Color(0xFFC84040);
    }
    final scale = Responsive.uiScale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 9 * scale),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 14 * scale,
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
    required this.onReturn,
  });

  final List<AssetRequest> requests;
  final void Function(AssetRequest request) onOpen;
  final void Function(AssetRequest request) onApprove;
  final void Function(AssetRequest request) onReject;
  final void Function(AssetRequest request) onCancel;
  final void Function(AssetRequest request) onReturn;

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
          Expanded(flex: 2, child: Text('Loan period', style: style)),
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
                  request.dateRangeLabel,
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
  ///
  /// Neither the approve nor the reject icon acts immediately — both open
  /// [RequestDetailScreen] (via [onApprove]/[onReject], wired to
  /// `_openRequestDetail`) so the admin reviews the full request before
  /// either decision is actually available.
  Widget _tableActions(AssetRequest request) {
    if (request.status == RequestStatus.pending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onApprove(request),
            icon: const Icon(Icons.check_circle_outline),
            color: AppTheme.primary,
            tooltip: 'Review to approve',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => onReject(request),
            icon: const Icon(Icons.cancel_outlined),
            color: Colors.redAccent,
            tooltip: 'Review to reject',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      );
    }
    if (request.status == RequestStatus.approved) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onReturn(request),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            color: AppTheme.primary,
            tooltip: 'Review to mark returned',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => onCancel(request),
            icon: const Icon(Icons.undo),
            color: AppTheme.muted,
            tooltip: 'Cancel approval',
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, this.onTap});

  final AssetRequest request;

  /// Invoked when the card is tapped. Wired up by [RequestsScreen] to open
  /// the request's detail page. This card is now just a compact, tappable
  /// summary — mirroring [AssetCard] on the Inventory tab — rather than a
  /// mini version of the detail screen: the requester, venue, itemized
  /// logistics/equipment, signatories, and the Approve/Reject/Cancel
  /// actions all live on [RequestDetailScreen] now, one tap away, instead
  /// of being crammed onto the card itself.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Same responsive scaling as AssetCard: `scale` shrinks smoothly with
    // a device's actual width and usable height (a skinny phone, or a
    // normal-width phone with a tall on-screen nav bar, both scale down)
    // instead of jumping between just a couple of fixed sizes.
    final scale = Responsive.uiScale(context);
    final imageSize = 68.0 * scale;
    final imageSpacing = 14.0 * scale;

    return Container(
      // The list wraps each card in a Center() (needed so the desktop
      // max-width cap can take effect), which hands this Container loose
      // width constraints. Without an explicit width it shrink-wraps to
      // its own content instead of filling the space it's given — and
      // since the title/subtext column below is Expanded (so it can
      // ellipsize instead of overflowing), an unbounded width here would
      // be a layout error rather than just a cosmetic issue.
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12 * scale),
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
            padding: EdgeInsets.all(14 * scale),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A plain icon tile stands in for AssetCard's item image —
                // requests don't have a photo of their own, so this just
                // marks the row as a request at a glance, the same way the
                // category icon does for an asset without a photo.
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: AppTheme.primary,
                    size: imageSize * .39,
                  ),
                ),
                SizedBox(width: imageSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.darkGreen,
                          fontSize: 17 * scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      // Just the department/org and the borrow date — the
                      // two facts that actually help someone tell requests
                      // apart while scanning the list. Everything else
                      // (requester, venue, items) is a tap away on the
                      // detail screen.
                      Text(
                        request.department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.muted, fontSize: 13 * scale),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        'Borrow ${request.dateRangeLabel}',
                        style: TextStyle(color: AppTheme.muted, fontSize: 12 * scale),
                      ),
                      SizedBox(height: 8 * scale),
                      _RequestStatusPill(status: request.status),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  SizedBox(width: 6 * scale),
                  Padding(
                    padding: EdgeInsets.only(top: 12 * scale),
                    child: Icon(Icons.chevron_right, color: AppTheme.muted, size: 24 * scale),
                  ),
                ],
              ],
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
class NewRequestForm extends StatefulWidget {
  const NewRequestForm({
    super.key,
    this.fullPage = false,
    this.initialRequester,
    this.initialDepartment,
  });

  final bool fullPage;

  /// Prefills "Requested by"/"Department / org" with the signed-in user's
  /// own name/department, when known.
  final String? initialRequester;
  final String? initialDepartment;

  @override
  State<NewRequestForm> createState() => _NewRequestFormState();
}

class _NewRequestFormState extends State<NewRequestForm> {
  final titleController = TextEditingController();
  late final requesterController = TextEditingController(text: widget.initialRequester ?? '');
  late final departmentController = TextEditingController(text: widget.initialDepartment ?? '');
  final venueController = TextEditingController();
  DateTime? borrowDate;
  DateTime? returnDate;

  // Each list always keeps at least one (possibly blank) row so the
  // section never looks empty; blank rows are simply skipped on submit.
  final logisticsRows = [_ItemFormRow()];
  final equipmentRows = [_ItemFormRow()];

  // The four signatory printed-name fields the paper slip always asks
  // for. The requester's printed name mirrors requesterController so it
  // doesn't have to be typed twice, but is kept as its own controller so
  // it can still be edited independently (e.g. someone else fills out
  // the form on the requester's behalf).
  final adviserNameController = TextEditingController();
  final principalNameController = TextEditingController();
  final deanNameController = TextEditingController();

  // A single photo/scan of the filled-out, signed CSDO Request Form —
  // all four signatures are visible on it, so there's no need to collect
  // a separate image per signatory.
  Uint8List? requestFormImageBytes;

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

  Future<void> _pickLoanPeriod() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: borrowDate != null && returnDate != null
          ? DateTimeRange(start: borrowDate!, end: returnDate!)
          : null,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        borrowDate = picked.start;
        returnDate = picked.end;
      });
    }
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
    if (borrowDate == null || returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the borrow and return dates.')),
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
        borrowDate: AssetItem.formatDate(borrowDate!),
        returnDate: AssetItem.formatDate(returnDate!),
        requesterSignature: Signatory(name: requesterName),
        adviserSignature: Signatory(name: adviserNameController.text.trim()),
        principalSignature: Signatory(name: principalNameController.text.trim()),
        deanSignature: Signatory(name: deanNameController.text.trim()),
        requestFormImageBytes: requestFormImageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullPage) return _mobilePage();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 740),
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
                      _loanPeriodField(),
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

  /// Full-screen mobile route. It avoids constraining the long request form
  /// to a dialog and keeps the primary action reachable while the fields
  /// scroll above it.
  Widget _mobilePage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New request', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Event / purpose', titleController, hint: 'e.g. Freshmen orientation'),
                    _field('Requested by', requesterController, hint: 'Your name'),
                    _field('Department / org', departmentController, hint: 'e.g. OSA'),
                    _field('Venue / facility', venueController, hint: 'e.g. Gymnasium — leave blank if none needed'),
                    _loanPeriodField(),
                    const SizedBox(height: 6),
                    _itemsSection('Logistics', logisticsRows, hint: 'e.g. Foldable chairs'),
                    const SizedBox(height: 10),
                    _itemsSection('Equipment', equipmentRows, hint: 'e.g. Wireless microphone'),
                    const SizedBox(height: 10),
                    _signaturesSection(),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
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
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          child: const Text('Submit request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

  Widget _loanPeriodField() => RequestDateRangeField(
        borrowDate: borrowDate,
        returnDate: returnDate,
        onTap: _pickLoanPeriod,
        formatDate: AssetItem.formatDate,
      );

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

  /// The "Signatures" section: the printed name for each role on the
  /// paper slip — requester, adviser, principal/office head, and dean —
  /// followed by a single photo/scan attachment of the filled-out,
  /// signed CSDO Request Form itself (all four signatures are visible on
  /// that one photo, so there's no need to upload one per person).
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
          'Enter each approver\'s printed name, then attach one photo or scan of the signed CSDO Request Form.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        _field('Requester (printed name)', requesterController, hint: 'Your name'),
        _field('Adviser (printed name)', adviserNameController),
        _field('Principal / Office Head (printed name)', principalNameController),
        _field('Dean (printed name)', deanNameController),
        const SizedBox(height: 4),
        RequestFormField(
          imageBytes: requestFormImageBytes,
          onImageChanged: (bytes) => setState(() => requestFormImageBytes = bytes),
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
/// amount) in [NewRequestForm].
class _ItemFormRow {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}