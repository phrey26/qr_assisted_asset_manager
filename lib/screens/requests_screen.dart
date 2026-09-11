import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/asset_request.dart';
import '../models/asset_return.dart';
import '../models/availability.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_assignment_sheet.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/page_header.dart';
import '../widgets/reason_dialog.dart';
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
  required Future<void> Function(AssetRequest request) onHandOut,
  required Future<void> Function(AssetRequest request) onMarkReturned,
  required void Function(AssetRequest request, RequestStatus status) onSetStatus,
  required Future<void> Function(AssetRequest request, String reason) onReject,
  required Future<void> Function(AssetRequest request, String reason) onWithdraw,
  required Future<void> Function(AssetRequest request) onEdit,
  required Future<bool> Function(AssetRequest request) onDelete,
  required Future<void> Function(
          AssetRequest request, ApprovalRole role, String decision, String? note)
      onRecordStep,
  required Future<void> Function(AssetRequest request, String body) onPostComment,
  String? adminName,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RequestDetailScreen(
        request: request,
        adminName: adminName,
        onApprove: () => onApprove(request),
        onHandOut: () => onHandOut(request),
        onMarkReturned: () => onMarkReturned(request),
        onReject: (reason) => onReject(request, reason),
        onCancel: () => onSetStatus(request, RequestStatus.pending),
        onWithdraw: (reason) => onWithdraw(request, reason),
        onEdit: () => onEdit(request),
        onDelete: () => onDelete(request),
        onRecordStep: (role, decision, note) =>
            onRecordStep(request, role, decision, note),
        onPostComment: (body) => onPostComment(request, body),
      ),
    ),
  );
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    this.currentUser,
    required this.assets,
    this.categories = const [],
    required this.onApplyAssetStatuses,
    required this.onApplyAssetCondition,
    required this.onApplyBulkOut,
    this.onCountsChanged,
  });

  /// The signed-in user's row from `user` (as returned by
  /// `csdo_api/login.php`) — used to prefill "Requested by"/"Department" on
  /// [NewRequestForm]. Null falls back to the form's own blank defaults.
  final Map<String, dynamic>? currentUser;

  /// The inventory categories, so a new request's logistics/equipment lines
  /// can optionally be linked to the pool they're asking for. Shared with
  /// the Inventory/Categories tabs (owned by `AppShell`).
  final List<AssetCategory> categories;

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

  /// Mirrors this screen's pending/overdue counts (`pendingCount` /
  /// `overdueCount` on [RequestsScreenState]) up to `AppShell` after every
  /// rebuild (initial load, an approval, a rejection, a return, a new
  /// request — any of them can change these), so the Home dashboard can
  /// show them without a second `fetchRequests()` call. See the wiring in
  /// `lib/main.dart`.
  final void Function(int pending, int overdue)? onCountsChanged;

  @override
  State<RequestsScreen> createState() => RequestsScreenState();
}

/// Public so [AppShell] can reach [openNewRequest] via a [GlobalKey] and
/// trigger it from the shared circular FAB, the same way it drives
/// [InventoryScreen]'s "add asset" flow.
class RequestsScreenState extends State<RequestsScreen> {
  /// Every chip [_filters] offers, and the only values [setFilter] accepts.
  /// Shared between the two so they can't drift apart.
  static const _filterOptions = [
    'All', 'Pending', 'Approved', 'Checked out', 'Overdue', 'Returned',
    'Rejected', 'Withdrawn',
  ];

  List<AssetRequest> requests = [];
  String filter = 'All';
  bool _loading = true;
  String? _loadError;

  /// Free-text search box, matching the same pattern already used on
  /// Inventory/Categories/Stock items/Removed assets — this was the one
  /// list screen in the app without one. See [_matchesQuery].
  final searchController = TextEditingController();

  /// Jumps straight to [value] (one of [_filterOptions]), replacing
  /// whatever filter was previously selected — the same way
  /// [InventoryScreenState.setFilter] jumps the Inventory tab to a given
  /// category. Used by the Home dashboard's "Pending requests" tile and
  /// "Overdue loans" row. Falls back to 'All' for anything this page
  /// doesn't recognize.
  void setFilter(String value) {
    setState(() => filter = _filterOptions.contains(value) ? value : 'All');
  }

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
    // Deferred to the next frame for the same reason [AppShell] does this
    // in main.dart: _loadRequests calls setState before its first `await`,
    // and calling that synchronously from initState (itself invoked while
    // the parent is still building) throws "setState() or markNeedsBuild()
    // called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRequests();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
    final statusFiltered = switch (filter) {
      'All' => requests,
      'Overdue' => requests.where((r) => r.isOverdue).toList(),
      _ => requests.where((r) => r.status.label == filter).toList(),
    };
    final query = searchController.text;
    final base = statusFiltered.where((r) => r.matchesSearch(query)).toList();
    // Overdue loans float to the top; the rest keep the server order
    // (newest first). Using two passes keeps it stable.
    return [
      ...base.where((r) => r.isOverdue),
      ...base.where((r) => !r.isOverdue),
    ];
  }

  int get pendingCount =>
      requests.where((r) => r.status == RequestStatus.pending).length;

  int get overdueCount => requests.where((r) => r.isOverdue).length;

  /// Applies [status] locally right away, then syncs it to the backend;
  /// reverted (with an error snackbar) if that call fails.
  ///
  /// Handles the transitions that touch no physical assets: rejecting a
  /// pending request, or cancelling an approval (which only *reserved* the
  /// assets — nothing was handed out). Handing out and returning go through
  /// [_handOut] / [_markReturned]; approving through [_approveRequest].
  Future<void> _setStatus(AssetRequest request, RequestStatus status) async {
    final previousStatus = request.status;
    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);

    setState(() {
      request.status = status;
      request.assignedAssets = const [];
    });
    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(id: request.id!, status: status.apiValue);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.assignedAssets = previousAssigned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update the request\'s status: $e')),
      );
    }
  }

  String? get _adminName => widget.currentUser?['full_name'] as String?;

  /// Opens [RequestDetailScreen] with every action wired to this state.
  void _openDetail(AssetRequest request) => _openRequestDetail(
        context,
        request,
        onApprove: _approveRequest,
        onHandOut: _handOut,
        onMarkReturned: _markReturned,
        onSetStatus: _setStatus,
        onReject: _rejectRequest,
        onWithdraw: _withdrawRequest,
        onEdit: _editRequest,
        onDelete: _deleteRequest,
        onRecordStep: _recordApprovalStep,
        onPostComment: _postCommentOn,
        adminName: _adminName,
      );

  /// CSDO rejection — carries the required reason, stored on the request and
  /// shown to the requester.
  Future<void> _rejectRequest(AssetRequest request, String reason) async {
    final previousStatus = request.status;
    final previousReason = request.rejectionReason;
    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);
    setState(() {
      request.status = RequestStatus.rejected;
      request.rejectionReason = reason;
      request.assignedAssets = const [];
    });
    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(
        id: request.id!,
        status: RequestStatus.rejected.apiValue,
        reason: reason,
        decidedBy: _adminName,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.rejectionReason = previousReason;
        request.assignedAssets = previousAssigned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject the request: $e')),
      );
    }
  }

  /// Withdraw — the office/requester pulls the request rather than CSDO
  /// declining it. Same shape as [_rejectRequest]: optimistic status flip
  /// with the reason kept, released reservation, rolled back on failure.
  Future<void> _withdrawRequest(AssetRequest request, String reason) async {
    final previousStatus = request.status;
    final previousReason = request.rejectionReason;
    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);
    setState(() {
      request.status = RequestStatus.withdrawn;
      request.rejectionReason = reason;
      request.assignedAssets = const [];
    });
    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(
        id: request.id!,
        status: RequestStatus.withdrawn.apiValue,
        reason: reason,
        decidedBy: _adminName,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.rejectionReason = previousReason;
        request.assignedAssets = previousAssigned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not withdraw the request: $e')),
      );
    }
  }

  /// Opens the edit form (only meaningful for a pending / rejected request)
  /// and applies the saved changes onto [request] in place. Editing a
  /// rejected request resubmits it: it goes back to pending and its routing
  /// is reset (matching the backend). Rolled back on a save failure.
  Future<void> _editRequest(AssetRequest request) async {
    if (request.status != RequestStatus.pending &&
        request.status != RequestStatus.rejected) {
      return;
    }
    final edited = await _showRequestForm(editing: request);
    if (edited == null || !mounted) return;

    // Snapshot every field the edit can touch, for rollback.
    final prev = (
      title: request.title,
      requester: request.requester,
      department: request.department,
      venue: request.venue,
      logistics: request.logistics,
      equipment: request.equipment,
      borrowDate: request.borrowDate,
      returnDate: request.returnDate,
      borrowOn: request.borrowOn,
      returnOn: request.returnOn,
      adviser: request.adviserSignature,
      principal: request.principalSignature,
      dean: request.deanSignature,
      formImage: request.requestFormImageBytes,
      status: request.status,
      reason: request.rejectionReason,
      approvals: request.approvals
          .map((a) => RequestApproval(
                role: a.role,
                seq: a.seq,
                status: a.status,
                printedName: a.printedName,
                note: a.note,
                decidedByName: a.decidedByName,
                decidedAt: a.decidedAt,
              ))
          .toList(),
    );
    final wasRejected = request.status == RequestStatus.rejected;

    setState(() {
      request.title = edited.title;
      request.requester = edited.requester;
      request.department = edited.department;
      request.venue = edited.venue;
      request.logistics = edited.logistics;
      request.equipment = edited.equipment;
      request.borrowDate = edited.borrowDate;
      request.returnDate = edited.returnDate;
      request.borrowOn = edited.borrowOn;
      request.returnOn = edited.returnOn;
      request.adviserSignature = edited.adviserSignature;
      request.principalSignature = edited.principalSignature;
      request.deanSignature = edited.deanSignature;
      request.requestFormImageBytes = edited.requestFormImageBytes;
      // Re-sync each routing row's printed name from the corrected form.
      for (final a in request.approvals) {
        final name = switch (a.role) {
          ApprovalRole.adviser => edited.adviserSignature.name,
          ApprovalRole.principal => edited.principalSignature.name,
          ApprovalRole.dean => edited.deanSignature.name,
        }.trim();
        a.printedName = name.isEmpty ? null : name;
      }
      // Editing a rejected request resubmits it.
      if (wasRejected) {
        request.status = RequestStatus.pending;
        request.rejectionReason = null;
        request.decidedByName = null;
        request.decidedAt = null;
        for (final a in request.approvals) {
          a.status = ApprovalStepStatus.pending;
          a.note = null;
          a.decidedByName = null;
          a.decidedAt = null;
        }
      }
    });

    if (request.id == null) return;
    try {
      await ApiService.editRequest(id: request.id!, body: edited.toEditJson());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.title = prev.title;
        request.requester = prev.requester;
        request.department = prev.department;
        request.venue = prev.venue;
        request.logistics = prev.logistics;
        request.equipment = prev.equipment;
        request.borrowDate = prev.borrowDate;
        request.returnDate = prev.returnDate;
        request.borrowOn = prev.borrowOn;
        request.returnOn = prev.returnOn;
        request.adviserSignature = prev.adviser;
        request.principalSignature = prev.principal;
        request.deanSignature = prev.dean;
        request.requestFormImageBytes = prev.formImage;
        request.status = prev.status;
        request.rejectionReason = prev.reason;
        request.approvals = prev.approvals;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the changes: $e')),
      );
    }
  }

  /// Permanently deletes a pending / rejected / withdrawn request after a
  /// required reason (kept in the backend's `request_removals` audit log).
  /// Returns true once the row is gone, so the detail screen can pop itself.
  Future<bool> _deleteRequest(AssetRequest request) async {
    final reason = await showReasonDialog(
      context,
      title: 'Delete this request',
      hint: 'This removes the request for good — use it only for a mistaken or '
          'duplicate entry. Why is it being deleted?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (reason == null || !mounted) return false;
    if (request.id == null) {
      setState(() => requests.remove(request));
      return true;
    }
    try {
      await ApiService.deleteRequest(
        request.id!,
        reason: reason,
        deletedBy: _adminName,
      );
      if (!mounted) return true;
      setState(() => requests.remove(request));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request deleted.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the request: $e')),
      );
      return false;
    }
  }

  /// Records one adviser/principal/dean routing decision and applies the
  /// backend's refreshed routing + status back onto [request] in place.
  Future<void> _recordApprovalStep(
    AssetRequest request,
    ApprovalRole role,
    String decision,
    String? note,
  ) async {
    if (request.id == null) return;
    try {
      final result = await ApiService.recordApprovalStep(
        requestId: request.id!,
        role: role,
        decision: decision,
        note: note,
        decidedBy: _adminName,
      );
      if (!mounted) return;
      setState(() {
        request.approvals = result.approvals;
        request.status = result.status;
        request.rejectionReason = result.rejectionReason;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record the decision: $e')),
      );
    }
  }

  /// Posts a comment and prepends it to [request]'s thread on success.
  Future<void> _postCommentOn(AssetRequest request, String body) async {
    if (request.id == null) return;
    try {
      final comment = await ApiService.postComment(
        requestId: request.id!,
        body: body,
        authorName: _adminName ?? 'CSDO',
      );
      if (!mounted) return;
      setState(() => request.comments = [comment, ...request.comments]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post the comment: $e')),
      );
    }
  }

  /// Approve flow: the admin picks the assets before the request can be
  /// approved. On confirm those assets are *reserved* for the loan window
  /// (a `request_assets` row each) — nothing is marked In use and no stock
  /// moves until the assets are handed out ([_handOut]). Re-approving
  /// replaces the previous reservation.
  Future<void> _approveRequest(AssetRequest request) async {
    // CSDO can only approve once adviser -> principal -> dean have all signed
    // (the backend enforces this too). Re-approving an already-approved
    // request to re-pick assets is still allowed.
    if (request.status == RequestStatus.pending && !request.chainComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request.chainRejected
                ? 'A routing step rejected this request — undo it before approving.'
                : 'Record the adviser, principal and dean approvals before CSDO approves.',
          ),
        ),
      );
      return;
    }

    final previousAssigned = List<AssignedAsset>.from(request.assignedAssets);
    final previousIndividualTags = previousAssigned
        .where((a) => !a.isBulk)
        .map((a) => a.tagId)
        .toList();
    final previousBulkQty = {
      for (final a in previousAssigned)
        if (a.isBulk) a.tagId: a.quantity,
    };

    // Load date-aware availability for this request's loan window so the
    // picker can show "N free for these dates" and lock assets already
    // booked for an overlapping period. Skipped when the request has no
    // comparable dates; a lookup failure just falls back to the
    // point-in-time figures (the backend still enforces the window on
    // approve).
    Map<String, AssetWindowAvailability>? windowAvailability;
    final from = AssetRequest.isoDate(request.borrowOn);
    final to = AssetRequest.isoDate(request.returnOn);
    if (from != null && to != null) {
      try {
        final report = await ApiService.fetchAvailability(
          from: from,
          to: to,
          excludeRequest: request.id,
        );
        windowAvailability = report.byTagId;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check availability for the loan dates: $e'),
          ),
        );
      }
    }
    if (!mounted) return;

    final picked = await showAssetAssignmentPicker(
      context,
      assets: widget.assets,
      request: request,
      preselectedTagIds: previousIndividualTags,
      preselectedQuantities: previousBulkQty,
      windowAvailability: windowAvailability,
    );
    if (!mounted || picked == null || picked.isEmpty) return;

    final previousStatus = request.status;

    setState(() {
      request.status = RequestStatus.approved;
      // Reserved, not out: individual assets stay `available` until hand-out.
      request.assignedAssets = [
        for (final p in picked)
          AssignedAsset(
            tagId: p.asset.tagId,
            name: p.asset.name,
            category: p.asset.category,
            status: AssetStatus.available,
            tracking: p.asset.tracking,
            quantity: p.asset.isBulk ? p.quantity : 1,
          ),
      ];
    });

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve the request: $e')),
      );
    }
  }

  /// Hand-out flow: an approved (reserved) request's assets are physically
  /// handed over now — individual units flip to In use, bulk pools decrement
  /// available stock. Locally optimistic, reverted on a backend failure.
  Future<void> _handOut(AssetRequest request) async {
    if (request.status != RequestStatus.approved) return;
    final previousStatus = request.status;
    final assigned = List<AssignedAsset>.from(request.assignedAssets);
    final individualTags =
        assigned.where((a) => !a.isBulk).map((a) => a.tagId).toList();
    final bulkDeltas = {
      for (final a in assigned)
        if (a.isBulk) a.tagId: a.quantity,
    };

    setState(() {
      request.status = RequestStatus.checkedOut;
      request.assignedAssets = assigned
          .map((a) => AssignedAsset(
                tagId: a.tagId,
                name: a.name,
                category: a.category,
                status: a.isBulk ? AssetStatus.available : AssetStatus.inUse,
                tracking: a.tracking,
                quantity: a.quantity,
              ))
          .toList();
    });
    if (individualTags.isNotEmpty) {
      widget.onApplyAssetStatuses(individualTags, AssetStatus.inUse);
    }
    if (bulkDeltas.isNotEmpty) widget.onApplyBulkOut(bulkDeltas);

    if (request.id == null) return;
    try {
      await ApiService.updateRequestStatus(
        id: request.id!,
        status: RequestStatus.checkedOut.apiValue,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        request.status = previousStatus;
        request.assignedAssets = assigned;
      });
      if (individualTags.isNotEmpty) {
        widget.onApplyAssetStatuses(individualTags, AssetStatus.available);
      }
      if (bulkDeltas.isNotEmpty) {
        widget.onApplyBulkOut({for (final e in bulkDeltas.entries) e.key: -e.value});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not hand out the assets: $e')),
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

  /// Shows the request form — full-screen route on mobile, dialog on
  /// desktop. [editing] non-null prefills it from that request and switches
  /// its labels to "Edit request" / "Save changes"; the returned
  /// [AssetRequest] then carries the same `id`.
  Future<AssetRequest?> _showRequestForm({AssetRequest? editing}) {
    final user = widget.currentUser;
    if (Responsive.isMobile(context)) {
      return Navigator.of(context).push<AssetRequest>(
        MaterialPageRoute(
          builder: (_) => NewRequestForm(
            fullPage: true,
            initialRequester: user?['full_name'] as String?,
            initialDepartment: user?['department'] as String?,
            categories: widget.categories,
            editing: editing,
          ),
        ),
      );
    }
    return showDialog<AssetRequest>(
      context: context,
      builder: (_) => NewRequestForm(
        initialRequester: user?['full_name'] as String?,
        initialDepartment: user?['department'] as String?,
        categories: widget.categories,
        editing: editing,
      ),
    );
  }

  Future<void> openNewRequest() async {
    final created = await _showRequestForm();
    if (created == null) return;

    try {
      final id = await ApiService.addRequest(created.toJson());
      if (!mounted) return;
      setState(() => requests.insert(0, AssetRequest.fromJson({...created.toJson(), 'id': id})));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit the request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Push the current pending/overdue counts up to AppShell after this
    // frame, so the Home dashboard can show them without having to
    // remember every place `requests` can change (a load, an approval, a
    // rejection, a hand-out, a return, a withdrawal, a new request — any
    // rebuild ends up here). Deferred for the same reason every other
    // cross-widget setState in this app is: triggering it synchronously
    // mid-build throws "setState() or markNeedsBuild() called during
    // build". AppShell only actually rebuilds when a count changed, so
    // this settles after at most one extra frame.
    final onCountsChanged = widget.onCountsChanged;
    if (onCountsChanged != null) {
      final pending = pendingCount;
      final overdue = overdueCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onCountsChanged(pending, overdue);
      });
    }

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
                        subtitle: overdueCount > 0
                            ? '$pendingCount pending · $overdueCount overdue'
                            : '$pendingCount pending approval',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 360 : double.infinity),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by title, requester, or department',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _filters(),
                  ],
                ),
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
                    onOpen: _openDetail,
                    onApprove: _openDetail,
                    onHandOut: _openDetail,
                    onReject: _openDetail,
                    onCancel: (request) => _setStatus(request, RequestStatus.pending),
                    onReturn: _openDetail,
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
                    onTap: () => _openDetail(filtered[index]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    return FilterChipRow(
      options: _filterOptions,
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
      case RequestStatus.checkedOut:
        background = AppTheme.mint;
        foreground = AppTheme.primary;
      case RequestStatus.returned:
      case RequestStatus.withdrawn:
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

/// Small red "Overdue · Nd" pill shown next to the status pill on any
/// checked-out request whose return date has passed.
class _OverduePill extends StatelessWidget {
  const _OverduePill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 7 * scale),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_outlined, size: 13 * scale, color: const Color(0xFFC84040)),
          SizedBox(width: 4 * scale),
          Text(
            'Overdue · ${days}d',
            style: TextStyle(
              color: const Color(0xFFC84040),
              fontWeight: FontWeight.w800,
              fontSize: 12.5 * scale,
            ),
          ),
        ],
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
    required this.onHandOut,
    required this.onReject,
    required this.onCancel,
    required this.onReturn,
  });

  final List<AssetRequest> requests;
  final void Function(AssetRequest request) onOpen;
  final void Function(AssetRequest request) onApprove;
  final void Function(AssetRequest request) onHandOut;
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
              SizedBox(
                width: _statusWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RequestStatusPill(status: request.status),
                    if (request.isOverdue) ...[
                      const SizedBox(height: 4),
                      _OverduePill(days: request.daysOverdue),
                    ],
                    if (request.status == RequestStatus.pending &&
                        request.approvals.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        request.routingSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: request.chainComplete ? AppTheme.primary : AppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
            onPressed: () => onHandOut(request),
            icon: const Icon(Icons.outbound_outlined),
            color: AppTheme.primary,
            tooltip: 'Review to hand out',
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
    if (request.status == RequestStatus.checkedOut) {
      return IconButton(
        onPressed: () => onReturn(request),
        icon: const Icon(Icons.assignment_turned_in_outlined),
        color: AppTheme.primary,
        tooltip: 'Review to mark returned',
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                      Wrap(
                        spacing: 6 * scale,
                        runSpacing: 6 * scale,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _RequestStatusPill(status: request.status),
                          if (request.isOverdue) _OverduePill(days: request.daysOverdue),
                        ],
                      ),
                      if (request.status == RequestStatus.pending &&
                          request.approvals.isNotEmpty) ...[
                        SizedBox(height: 6 * scale),
                        Row(
                          children: [
                            Icon(Icons.how_to_reg_outlined,
                                size: 13 * scale, color: AppTheme.muted),
                            SizedBox(width: 4 * scale),
                            Expanded(
                              child: Text(
                                request.routingSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: request.chainComplete
                                      ? AppTheme.primary
                                      : AppTheme.muted,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((request.status == RequestStatus.rejected ||
                              request.status == RequestStatus.withdrawn) &&
                          request.rejectionReason != null) ...[
                        SizedBox(height: 6 * scale),
                        Text(
                          '${request.status == RequestStatus.withdrawn ? 'Withdrawn' : 'Rejected'}: '
                          '${request.rejectionReason}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: request.status == RequestStatus.withdrawn
                                ? AppTheme.muted
                                : const Color(0xFFC84040),
                            fontSize: 12 * scale,
                          ),
                        ),
                      ],
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
    this.categories = const [],
    this.editing,
  });

  final bool fullPage;

  /// Prefills "Requested by"/"Department / org" with the signed-in user's
  /// own name/department, when known.
  final String? initialRequester;
  final String? initialDepartment;

  /// Inventory categories offered as an optional "link to inventory" choice
  /// on each logistics/equipment line. Empty hides that field entirely.
  final List<AssetCategory> categories;

  /// When non-null the form opens in "edit" mode: every field is prefilled
  /// from this request, the headings read "Edit request" / "Save changes",
  /// and the returned [AssetRequest] carries the same `id`. Only ever passed
  /// for a pending / rejected request.
  final AssetRequest? editing;

  @override
  State<NewRequestForm> createState() => _NewRequestFormState();
}

class _NewRequestFormState extends State<NewRequestForm> {
  // Every field falls back to its "edit" value first (when the form was
  // opened on an existing request), then the signed-in user's defaults,
  // then blank.
  late final titleController =
      TextEditingController(text: widget.editing?.title ?? '');
  late final requesterController = TextEditingController(
      text: widget.editing?.requester ?? widget.initialRequester ?? '');
  late final departmentController = TextEditingController(
      text: widget.editing?.department ?? widget.initialDepartment ?? '');
  late final venueController =
      TextEditingController(text: widget.editing?.venue ?? '');
  late DateTime? borrowDate = widget.editing?.borrowOn;
  late DateTime? returnDate = widget.editing?.returnOn;

  // Each list always keeps at least one (possibly blank) row so the
  // section never looks empty; blank rows are simply skipped on submit.
  late final List<_ItemFormRow> logisticsRows =
      _initialRows(widget.editing?.logistics);
  late final List<_ItemFormRow> equipmentRows =
      _initialRows(widget.editing?.equipment);

  // The four signatory printed-name fields the paper slip always asks
  // for. The requester's printed name mirrors requesterController so it
  // doesn't have to be typed twice, but is kept as its own controller so
  // it can still be edited independently (e.g. someone else fills out
  // the form on the requester's behalf).
  late final adviserNameController =
      TextEditingController(text: widget.editing?.adviserSignature.name ?? '');
  late final principalNameController =
      TextEditingController(text: widget.editing?.principalSignature.name ?? '');
  late final deanNameController =
      TextEditingController(text: widget.editing?.deanSignature.name ?? '');

  // A single photo/scan of the filled-out, signed CSDO Request Form —
  // all four signatures are visible on it, so there's no need to collect
  // a separate image per signatory.
  late Uint8List? requestFormImageBytes = widget.editing?.requestFormImageBytes;

  bool get _isEditing => widget.editing != null;

  static List<_ItemFormRow> _initialRows(List<RequestedItem>? items) {
    if (items == null || items.isEmpty) return [_ItemFormRow()];
    return [
      for (final it in items)
        _ItemFormRow(
          name: it.name,
          quantity: it.quantity,
          categoryValue: it.categoryValue,
        ),
    ];
  }

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
      // The window changed — re-check every linked line against the new dates.
      for (final row in [...logisticsRows, ...equipmentRows]) {
        _scheduleFeasibility(row);
      }
    }
  }

  /// Debounced, coarse availability check for one linked line. Fires only
  /// when the line has a category, valid dates and a positive quantity;
  /// otherwise it just clears any stale outlook. The endpoint it calls
  /// (`request_feasibility.php`) returns a bucket only — no inventory detail.
  void _scheduleFeasibility(_ItemFormRow row) {
    row.debounce?.cancel();
    row.debounce = Timer(
      const Duration(milliseconds: 500),
      () => _runFeasibility(row),
    );
  }

  Future<void> _runFeasibility(_ItemFormRow row) async {
    final category = row.categoryValue;
    final b = borrowDate;
    final r = returnDate;
    final rawQty = row.quantityController.text.trim();
    final qty = rawQty.isEmpty ? 1 : int.tryParse(rawQty);
    if (category == null || b == null || r == null || qty == null || qty <= 0) {
      if (row.feasibilityOutlook != null || row.feasibilityLoading) {
        setState(() {
          row.feasibilityOutlook = null;
          row.feasibilityLoading = false;
        });
      }
      return;
    }
    setState(() => row.feasibilityLoading = true);
    try {
      final outlook = await ApiService.fetchRequestFeasibility(
        category: category,
        from: AssetRequest.isoDate(b)!,
        to: AssetRequest.isoDate(r)!,
        quantity: qty,
      );
      if (!mounted) return;
      setState(() {
        row.feasibilityOutlook = outlook;
        row.feasibilityLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        row.feasibilityOutlook = null;
        row.feasibilityLoading = false;
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
      items.add(RequestedItem(
        name: name,
        quantity: quantity,
        categoryValue: row.categoryValue,
      ));
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
        id: widget.editing?.id,
        title: titleController.text.trim(),
        requester: requesterName,
        department:
            departmentController.text.trim().isEmpty ? 'CSDO' : departmentController.text.trim(),
        venue: venue.isEmpty ? null : venue,
        logistics: logistics,
        equipment: equipment,
        borrowDate: AssetItem.formatDate(borrowDate!),
        returnDate: AssetItem.formatDate(returnDate!),
        borrowOn: borrowDate,
        returnOn: returnDate,
        requesterSignature: Signatory(name: requesterName),
        adviserSignature: Signatory(name: adviserNameController.text.trim()),
        principalSignature: Signatory(name: principalNameController.text.trim()),
        deanSignature: Signatory(name: deanNameController.text.trim()),
        requestFormImageBytes: requestFormImageBytes,
        // The backend seeds its own routing rows; these mirror them so the
        // request shows its pending steps before the first reload.
        approvals: [
          RequestApproval(
            role: ApprovalRole.adviser,
            seq: 1,
            status: ApprovalStepStatus.pending,
            printedName: _blankToNull(adviserNameController.text),
          ),
          RequestApproval(
            role: ApprovalRole.principal,
            seq: 2,
            status: ApprovalStepStatus.pending,
            printedName: _blankToNull(principalNameController.text),
          ),
          RequestApproval(
            role: ApprovalRole.dean,
            seq: 3,
            status: ApprovalStepStatus.pending,
            printedName: _blankToNull(deanNameController.text),
          ),
        ],
      ),
    );
  }

  static String? _blankToNull(String s) => s.trim().isEmpty ? null : s.trim();

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
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit request' : 'New request',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      child: Text(_isEditing ? 'Save changes' : 'Submit request'),
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
        title: Text(_isEditing ? 'Edit request' : 'New request',
            style: const TextStyle(fontWeight: FontWeight.w800)),
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
                          child: Text(_isEditing ? 'Save changes' : 'Submit request'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  onChanged: (_) => _scheduleFeasibility(row),
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
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: row.categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.link, size: 18),
                hintText: 'Link to an inventory category (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not linked — free text'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem<String?>(
                    value: category.value,
                    child: Text(category.displayName),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  row.categoryValue = value;
                  if (value == null) row.feasibilityOutlook = null;
                });
                _scheduleFeasibility(row);
              },
            ),
            if (row.feasibilityLoading || row.feasibilityOutlook != null) ...[
              const SizedBox(height: 4),
              _feasibilityHint(row),
            ],
          ],
        ],
      ),
    );
  }

  /// A coarse availability hint for a linked line. Deliberately shows only
  /// the outlook bucket from `request_feasibility.php` — never counts, asset
  /// names, or which requests hold what — so a requester can't read the
  /// inventory off this form.
  Widget _feasibilityHint(_ItemFormRow row) {
    if (row.feasibilityLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Checking availability for your dates…',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      );
    }
    final (IconData icon, Color color, String text) = switch (row.feasibilityOutlook) {
      'ok' => (
          Icons.check_circle_outline,
          AppTheme.primary,
          'Likely available for your dates',
        ),
      'partial' => (
          Icons.error_outline,
          const Color(0xFF9A6512),
          'Limited for your dates — the office will confirm what it can provide',
        ),
      'none' => (
          Icons.highlight_off,
          const Color(0xFFC84040),
          'Not available for your dates — the office may offer an alternative',
        ),
      _ => (
          Icons.help_outline,
          AppTheme.muted,
          'Availability will be confirmed by the office',
        ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// Holds the state for one logistics/equipment row in [NewRequestForm] —
/// the item name and amount controllers, an optional link to the inventory
/// category being asked for, and the coarse availability outlook for that
/// category + the request's dates (from `request_feasibility.php`).
class _ItemFormRow {
  _ItemFormRow({String? name, int? quantity, this.categoryValue}) {
    if (name != null && name.isNotEmpty) nameController.text = name;
    if (quantity != null && quantity > 0) quantityController.text = '$quantity';
  }

  final nameController = TextEditingController();
  final quantityController = TextEditingController();

  /// The [AssetCategory.value] this line is linked to, or null for free text.
  String? categoryValue;

  /// `'ok' | 'partial' | 'none' | 'unknown'`, or null when not linked / not
  /// yet checked. Never carries counts or item details.
  String? feasibilityOutlook;
  bool feasibilityLoading = false;
  Timer? debounce;

  void dispose() {
    debounce?.cancel();
    nameController.dispose();
    quantityController.dispose();
  }
}