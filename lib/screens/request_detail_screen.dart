import 'package:flutter/material.dart';

import '../models/asset_request.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/reason_dialog.dart';
import '../widgets/status_chip.dart';

/// Full detail view for a single asset request. Shows every field the
/// requester entered, the adviser → principal → dean routing (transcribed
/// from the photo of the signed form), the comment thread, and the
/// approve/hand-out/return/reject/cancel actions.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.request,
    this.adminName,
    this.onApprove,
    this.onHandOut,
    this.onMarkReturned,
    this.onReject,
    this.onCancel,
    this.onRecordStep,
    this.onPostComment,
  });

  final AssetRequest request;

  /// The signed-in admin's name, stamped on decisions and comments.
  final String? adminName;

  /// Invoked when the admin approves a pending request. Opens the asset
  /// picker and completes once the request has been approved (its assets
  /// reserved) or the admin backed out. When null, no approve action is
  /// shown (mirrors [onReject]/[onCancel]).
  final Future<void> Function()? onApprove;

  /// Invoked when the admin hands the reserved assets over for an approved
  /// request — flipping them to physically out. Completes once the backend
  /// has been updated.
  final Future<void> Function()? onHandOut;

  /// Invoked when the admin marks a checked-out request's borrowed assets as
  /// returned — freeing them and closing the loan. Completes once the
  /// backend has been updated.
  final Future<void> Function()? onMarkReturned;

  /// Invoked when the admin rejects the request — carries the required
  /// reason.
  final Future<void> Function(String reason)? onReject;

  /// Invoked when the admin cancels a previously-approved request, moving
  /// it back to pending.
  final VoidCallback? onCancel;

  /// Invoked when the admin records one routing decision — `decision` is
  /// `'approved'`, `'rejected'` or `'pending'` (undo); `note` carries the
  /// remark / rejection reason.
  final Future<void> Function(ApprovalRole role, String decision, String? note)?
      onRecordStep;

  /// Invoked when the admin posts a comment on the request.
  final Future<void> Function(String body)? onPostComment;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _commentController = TextEditingController();
  bool _postingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    await widget.onApprove?.call();
    if (mounted) setState(() {});
  }

  Future<void> _handOut() async {
    await widget.onHandOut?.call();
    if (mounted) setState(() {});
  }

  Future<void> _markReturned() async {
    await widget.onMarkReturned?.call();
    if (mounted) setState(() {});
  }

  Future<void> _reject() async {
    final reason = await showReasonDialog(
      context,
      title: 'Reject this request',
      hint: 'Why is it being declined? The requester will see this.',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    await widget.onReject?.call(reason);
    if (mounted) setState(() {});
  }

  void _cancel() {
    widget.onCancel?.call();
    setState(() {});
  }

  Future<void> _recordStep(ApprovalRole role, String decision) async {
    String? note;
    if (decision == 'rejected') {
      note = await showReasonDialog(
        context,
        title: 'Reject at ${role.label}',
        hint: 'Why did this step not endorse the request? '
            'The requester will see this.',
        confirmLabel: 'Reject',
        destructive: true,
      );
      if (note == null) return;
    }
    await widget.onRecordStep?.call(role, decision, note);
    if (mounted) setState(() {});
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _postingComment) return;
    setState(() => _postingComment = true);
    await widget.onPostComment?.call(text);
    if (!mounted) return;
    setState(() {
      _postingComment = false;
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request details'),
      ),
      body: SafeArea(
        child: Responsive.isDesktop(context)
            ? _desktopBody(request)
            : _mobileBody(request),
      ),
    );
  }

  Widget _mobileBody(AssetRequest request) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _requestHeading(request),
            if (request.isOverdue) ...[
              const SizedBox(height: 20),
              _overdueBanner(request),
            ],
            const SizedBox(height: 24),
            _infoCard(request),
            const SizedBox(height: 24),
            _routingCard(request),
            const SizedBox(height: 24),
            _signaturesCard(request),
            const SizedBox(height: 24),
            _commentsCard(request),
            const SizedBox(height: 24),
            _actions(request),
          ],
        ),
      );

  /// Desktop mirrors [AssetDetailScreen]'s constrained, centered layout so
  /// the two detail pages feel consistent.
  Widget _desktopBody(AssetRequest request) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 56),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _requestHeading(request, desktop: true),
                if (request.isOverdue) ...[
                  const SizedBox(height: 24),
                  _overdueBanner(request),
                ],
                const SizedBox(height: 30),
                _infoCard(request, desktop: true),
                const SizedBox(height: 24),
                _routingCard(request),
                const SizedBox(height: 24),
                _signaturesCard(request, desktop: true),
                const SizedBox(height: 24),
                _commentsCard(request),
                const SizedBox(height: 24),
                _actions(request, desktop: true),
              ],
            ),
          ),
        ),
      );

  /// The tint/icon pair to show for [status] — the same tint colors as
  /// [_RequestStatusPill], so the heading's avatar and the pill next to it
  /// always agree on what a given status "looks like".
  (Color, Color, IconData) _statusVisual(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return (AppTheme.cream, const Color(0xFF9A6512), Icons.hourglass_top_rounded);
      case RequestStatus.approved:
        return (AppTheme.mint, AppTheme.primary, Icons.event_available_outlined);
      case RequestStatus.checkedOut:
        return (AppTheme.mint, AppTheme.primary, Icons.outbound_outlined);
      case RequestStatus.returned:
        return (AppTheme.slateTint, AppTheme.muted, Icons.assignment_turned_in_outlined);
      case RequestStatus.rejected:
        return (AppTheme.redTint, const Color(0xFFC84040), Icons.highlight_off);
    }
  }

  /// Desktop gets a full "hero" card — a soft, flat status-tinted wash
  /// behind a larger status avatar, the request title, and the requester —
  /// mirroring [AssetDetailScreen]'s desktop heading treatment. Mobile
  /// keeps a plain background with just a compact avatar, so the two
  /// platforms read as related but visually distinct rather than the same
  /// row simply resized.
  Widget _requestHeading(AssetRequest request, {bool desktop = false}) {
    final (statusTint, statusColor, statusIcon) = _statusVisual(request.status);

    final avatar = Container(
      width: desktop ? 64 : 48,
      height: desktop ? 64 : 48,
      decoration: BoxDecoration(color: statusTint, shape: BoxShape.circle),
      child: Icon(statusIcon, color: statusColor, size: desktop ? 28 : 22),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        SizedBox(width: desktop ? 20 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.title,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: desktop ? 32 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                request.requester,
                style: const TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RequestStatusPill(status: request.status),
      ],
    );

    if (!desktop) return row;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: statusTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: row,
    );
  }

  /// Red banner on a checked-out request whose return date has passed.
  Widget _overdueBanner(AssetRequest request) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.alarm_outlined, color: Color(0xFFC84040)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This loan is ${request.overdueLabel}',
                  style: const TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The assets were due back ${request.returnDate} and have not been '
                  'returned. Follow up with ${request.requester}, then mark the '
                  'request returned once the assets are back.',
                  style: const TextStyle(color: Color(0xFFC84040), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(AssetRequest request, {bool desktop = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop) ...[
            const Text(
              'Request information',
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _detailRow('Requested by', request.requester)),
                Expanded(child: _detailRow('Department / org', request.department)),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _detailRow('Venue / facility', request.venue ?? 'Not requested')),
                Expanded(child: _detailRow('Borrow / return', request.dateRangeLabel)),
              ],
            ),
          ] else ...[
            _detailRow('Requested by', request.requester),
            _detailRow('Department / org', request.department),
            _detailRow('Venue / facility', request.venue ?? 'Not requested'),
            _detailRow('Borrow / return', request.dateRangeLabel),
          ],
          if (request.logistics.isNotEmpty) _itemsRow('Logistics', request.logistics),
          if (request.equipment.isNotEmpty) _itemsRow('Equipment', request.equipment),
          if (request.assignedAssets.isNotEmpty)
            _assignedAssetsRow(request.assignedAssets, status: request.status),
          _detailRow('Status', request.status.label, isLast: true),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: AppTheme.muted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Renders a labeled list of logistics/equipment lines, each with its
  /// requested amount (e.g. "Foldable chairs" · "× 120").
  Widget _itemsRow(String label, List<RequestedItem> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(color: AppTheme.muted, fontSize: 16),
                        ),
                        if (item.categoryValue != null)
                          Text(
                            'Linked to ${item.categoryValue} inventory',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '× ${item.quantity}',
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The real inventory assets tied to this request (picked by the admin on
  /// approval). While the request is only [RequestStatus.approved] they're
  /// *reserved* — shown with a neutral "Reserved" tag, since nothing has
  /// physically moved yet. Once [RequestStatus.checkedOut] each shows its
  /// live status / "on loan" count; once [RequestStatus.returned] a plain
  /// "Returned" tag, as the assets are back in the pool by then.
  Widget _assignedAssetsRow(
    List<AssignedAsset> assets, {
    required RequestStatus status,
  }) {
    final returned = status == RequestStatus.returned;
    final reserved = status == RequestStatus.approved;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reserved ? 'Reserved assets' : 'Assigned assets',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          for (final asset in assets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.isBulk ? '${asset.name}  ×${asset.quantity}' : asset.name,
                          style: const TextStyle(color: AppTheme.muted, fontSize: 16),
                        ),
                        Text(
                          asset.tagId,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (returned)
                    _pill('Returned', AppTheme.slateTint, AppTheme.muted)
                  else if (reserved)
                    _pill(
                      asset.isBulk ? '${asset.quantity} reserved' : 'Reserved',
                      AppTheme.slateTint,
                      AppTheme.darkGreen,
                    )
                  else if (asset.isBulk)
                    _pill('${asset.quantity} on loan', AppTheme.cream, const Color(0xFF9A6512))
                  else
                    StatusChip(status: asset.status),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Text(
          text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: child,
      );

  Widget _cardTitle(String text, {Widget? trailing}) => Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      );

  /// The signed CSDO form: the requester's printed name, plus the single
  /// photo/scan of the physically signed slip. Every routing decision on
  /// this page is transcribed from that photo, so it stays front and centre.
  Widget _signaturesCard(AssetRequest request, {bool desktop = false}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'Signed CSDO form',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  request.hasRequestForm ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: request.hasRequestForm ? AppTheme.primary : AppTheme.muted,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  request.hasRequestForm ? 'Photo attached' : 'No photo yet',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _detailRow('Requester (printed name)',
              request.requesterSignature.name.isEmpty ? '—' : request.requesterSignature.name),
          const SizedBox(height: 4),
          const Text(
            'Check the photo below against each routing step.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          _requestFormAttachment(request),
        ],
      ),
    );
  }

  /// The adviser → principal → dean routing, transcribed by the admin from
  /// the signed form. Each step shows its state, who recorded it and when,
  /// and any note; a still-pending request gets Approve / Reject / Undo
  /// actions in order. CSDO can only approve the whole request once all
  /// three are green (the last row here reflects that CSDO step).
  Widget _routingCard(AssetRequest request) {
    final steps = [...request.approvals]..sort((a, b) => a.seq.compareTo(b.seq));
    final locked = request.status != RequestStatus.pending &&
        request.status != RequestStatus.rejected;
    final actionable = widget.onRecordStep != null && !locked;

    // A step can be approved only once every earlier step is approved.
    bool priorAllApproved(int seq) =>
        steps.where((s) => s.seq < seq).every((s) => s.isApproved);
    // A step can be undone only if no later step is approved.
    bool noLaterApproved(int seq) =>
        steps.where((s) => s.seq > seq).every((s) => !s.isApproved);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Approval routing',
              trailing: _routingSummaryChip(request)),
          const SizedBox(height: 6),
          const Text(
            'Recorded from the signed form as it moves adviser → principal / office '
            'head → dean. CSDO can approve once all three have signed.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 8),
          for (final step in steps) ...[
            const Divider(height: 22, color: AppTheme.border),
            _stepRow(
              step,
              actionable: actionable,
              canApprove: priorAllApproved(step.seq),
              canUndo: noLaterApproved(step.seq),
            ),
          ],
          const Divider(height: 22, color: AppTheme.border),
          _csdoStepRow(request),
        ],
      ),
    );
  }

  Widget _routingSummaryChip(AssetRequest request) {
    final (bg, fg) = request.chainRejected
        ? (AppTheme.redTint, const Color(0xFFC84040))
        : request.chainComplete
            ? (AppTheme.mint, AppTheme.primary)
            : (AppTheme.cream, const Color(0xFF9A6512));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        request.routingSummary,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  Widget _stepRow(
    RequestApproval step, {
    required bool actionable,
    required bool canApprove,
    required bool canUndo,
  }) {
    final (icon, tint) = switch (step.status) {
      ApprovalStepStatus.approved => (Icons.check_circle, AppTheme.primary),
      ApprovalStepStatus.rejected => (Icons.cancel, const Color(0xFFC84040)),
      ApprovalStepStatus.pending => (Icons.radio_button_unchecked, AppTheme.muted),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tint, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.role.label,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    step.printedName == null || step.printedName!.isEmpty
                        ? 'No printed name on the form'
                        : 'Signed over: ${step.printedName}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
                  ),
                  if (step.decidedAt != null)
                    Text(
                      '${step.status.label} · ${_stamp(step.decidedAt!)}'
                      '${step.decidedByName == null ? '' : ' · by ${step.decidedByName}'}',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
                    ),
                  if (step.note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.note!,
                      style: TextStyle(
                        color: step.isRejected ? const Color(0xFFC84040) : AppTheme.muted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (actionable) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (step.status != ApprovalStepStatus.approved)
                _stepBtn('Approve', Icons.check, AppTheme.primary,
                    canApprove ? () => _recordStep(step.role, 'approved') : null),
              if (step.status != ApprovalStepStatus.rejected)
                _stepBtn('Reject', Icons.close, const Color(0xFFC84040),
                    () => _recordStep(step.role, 'rejected')),
              if (step.status != ApprovalStepStatus.pending)
                _stepBtn('Undo', Icons.undo, AppTheme.muted,
                    canUndo ? () => _recordStep(step.role, 'pending') : null),
            ],
          ),
        ],
      ],
    );
  }

  Widget _stepBtn(String label, IconData icon, Color color, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: onTap == null ? AppTheme.border : color, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// The 4th "step" — CSDO's own decision — reflected read-only from the
  /// request's status. It's acted on with the Approve / Reject buttons in
  /// [_actions] below, and only unlocks once the three above are green.
  Widget _csdoStepRow(AssetRequest request) {
    final (icon, tint, label) = switch (request.status) {
      RequestStatus.rejected => (Icons.cancel, const Color(0xFFC84040), 'Rejected'),
      RequestStatus.pending => request.chainComplete
          ? (Icons.pending_outlined, const Color(0xFF9A6512), 'Ready for CSDO')
          : (Icons.lock_outline, AppTheme.muted, 'Waiting on signatories'),
      _ => (Icons.check_circle, AppTheme.primary, 'Approved by CSDO'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tint, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CSDO',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: tint, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              if (request.decidedAt != null)
                Text(
                  '${_stamp(request.decidedAt!)}'
                  '${request.decidedByName == null ? '' : ' · by ${request.decidedByName}'}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
                ),
              if (request.rejectionReason != null) ...[
                const SizedBox(height: 2),
                Text(
                  request.rejectionReason!,
                  style: const TextStyle(
                    color: Color(0xFFC84040),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Sep 16, 2:45 PM" for an activity stamp.
  static String _stamp(DateTime at) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    final ap = at.hour < 12 ? 'AM' : 'PM';
    return '${months[at.month - 1]} ${at.day}, $h:$m $ap';
  }

  /// The comment thread: existing notes newest-first, then a compose box.
  Widget _commentsCard(AssetRequest request) {
    final comments = request.comments;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Comments & activity'),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            const Text(
              'No comments yet. Use this to note what a request is waiting on, '
              'or why it needs to be resubmitted.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
            )
          else
            for (var i = 0; i < comments.length; i++) ...[
              if (i > 0) const Divider(height: 22, color: AppTheme.border),
              _commentTile(comments[i]),
            ],
          if (widget.onPostComment != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Add a comment…'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _commentController.text.trim().isEmpty || _postingComment
                    ? null
                    : _postComment,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Post'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _commentTile(RequestComment c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.authorName,
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              _stamp(c.createdAt),
              style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(c.body, style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4)),
      ],
    );
  }

  /// The attached photo/scan of the filled-out, signed CSDO Request
  /// Form — shown once here in place of a per-signatory signature image,
  /// since all four signatures are already visible on this one photo.
  /// Tapping the photo opens it full-screen (image viewing mode) so the
  /// signatures can actually be read closely.
  Widget _requestFormAttachment(AssetRequest request) {
    final bytes = request.requestFormImageBytes;
    const heroTag = 'request-form-image';
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 220,
        color: const Color(0xFFF3FAF7),
        child: bytes == null
            ? const Center(
                child: Text(
                  'No CSDO Request Form photo attached',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              )
            : Hero(tag: heroTag, child: Image.memory(bytes, fit: BoxFit.contain)),
      ),
    );

    if (bytes == null) return image;

    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => ImageViewerScreen.open(
            context,
            imageBytes: bytes,
            heroTag: heroTag,
            title: 'CSDO Request Form',
          ),
          child: image,
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Tap to view',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Danger styling for the "Reject" action — a red outline/text instead
  /// of the default theme-primary (green) [OutlinedButton], so a rejection
  /// reads as visually distinct from (and more consequential than) the
  /// neutral "Cancel approval" action below, rather than the two sharing
  /// the same green outline. [desktop] additionally trims the button down
  /// from the global theme's full-height mobile sizing.
  static ButtonStyle _rejectStyle({bool desktop = false}) => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC84040),
        side: const BorderSide(color: Color(0xFFC84040), width: 2),
        minimumSize: desktop ? _desktopMinSize : null,
        padding: desktop ? _desktopButtonPadding : null,
      );

  /// Neutral-but-clickable styling for "Cancel approval". A plain outline
  /// (as this used to be) reads as disabled on a phone screen — outlined
  /// buttons lean on a hover/pointer affordance touch devices don't have,
  /// so with nothing but a faint grey border it looked inert rather than
  /// tappable. A soft filled background (plus a small icon) gives it the
  /// same "this is a button" weight as Approve/Reject, while staying
  /// visually calmer than either so it still reads as the lower-stakes,
  /// reversible action.
  static ButtonStyle _cancelStyle({bool desktop = false}) => FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE8ECEA),
        foregroundColor: AppTheme.darkGreen,
        side: const BorderSide(color: Color(0xFFD3DBD8), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        minimumSize: desktop ? _desktopMinSize : const Size.fromHeight(56),
        padding: desktop ? _desktopButtonPadding : const EdgeInsets.symmetric(horizontal: 24),
      );

  /// Compact sizing for desktop action buttons, overriding the global
  /// button theme's `Size.fromHeight(64)` (sized for full-width mobile
  /// buttons), so desktop doesn't end up with two edge-to-edge, 64px-tall
  /// buttons that were clearly sized for a phone screen.
  static const _desktopButtonPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 14);
  static const _desktopMinSize = Size(0, 48);

  /// Approve/reject (pending) or cancel (approved) actions, matching what
  /// used to be available only from the request card on the list page.
  ///
  /// Mobile keeps a full-width button (or button pair) — a large, easy
  /// thumb target at the bottom of the scrolling page. Desktop instead
  /// wraps the same actions in a card with compact, right-aligned buttons,
  /// matching the "New request" button's desktop-sized override elsewhere
  /// in the app, so the page ends in a proper action bar instead of
  /// stretched mobile-sized buttons.
  Widget _actions(AssetRequest request, {bool desktop = false}) {
    if (request.status == RequestStatus.pending) {
      final chainReady = request.chainComplete;
      final approve = ElevatedButton.icon(
        onPressed: widget.onApprove == null || !chainReady ? null : _approve,
        style: desktop
            ? ElevatedButton.styleFrom(
                minimumSize: _desktopMinSize,
                padding: _desktopButtonPadding,
              )
            : null,
        icon: Icon(chainReady ? Icons.check : Icons.lock_outline, size: 18),
        label: const Text('Approve (CSDO)'),
      );
      final reject = OutlinedButton(
        onPressed: widget.onReject == null ? null : _reject,
        style: _rejectStyle(desktop: desktop),
        child: const Text('Reject'),
      );
      final hint = Text(
        chainReady
            ? 'Adviser, principal and dean have all signed — CSDO can now approve '
                'and assign assets.'
            : 'Record the adviser, principal and dean approvals above before CSDO '
                'can approve this request.',
        textAlign: desktop ? TextAlign.right : TextAlign.center,
        style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
      );
      if (!desktop) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: approve),
                const SizedBox(width: 12),
                Expanded(child: reject),
              ],
            ),
            const SizedBox(height: 10),
            hint,
          ],
        );
      }
      return _desktopActionsBar([
        Expanded(child: hint),
        const SizedBox(width: 16),
        reject,
        const SizedBox(width: 12),
        approve,
      ]);
    }
    if (request.status == RequestStatus.approved) {
      final handOut = ElevatedButton.icon(
        onPressed: widget.onHandOut == null ? null : _handOut,
        style: desktop
            ? ElevatedButton.styleFrom(
                minimumSize: _desktopMinSize,
                padding: _desktopButtonPadding,
              )
            : null,
        icon: const Icon(Icons.outbound_outlined, size: 20),
        label: const Text('Hand out assets'),
      );
      final cancel = FilledButton.icon(
        onPressed: widget.onCancel == null ? null : _cancel,
        style: _cancelStyle(desktop: desktop),
        icon: const Icon(Icons.undo, size: 18),
        label: const Text('Cancel approval'),
      );
      if (!desktop) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            handOut,
            const SizedBox(height: 10),
            cancel,
            const SizedBox(height: 10),
            const Text(
              'The assets are reserved for these dates. Handing them out marks '
              'them physically borrowed; cancelling releases the reservation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        );
      }
      return _desktopActionsBar([cancel, const SizedBox(width: 12), handOut]);
    }
    if (request.status == RequestStatus.checkedOut) {
      final markReturned = ElevatedButton.icon(
        onPressed: widget.onMarkReturned == null ? null : _markReturned,
        style: desktop
            ? ElevatedButton.styleFrom(
                minimumSize: _desktopMinSize,
                padding: _desktopButtonPadding,
              )
            : null,
        icon: const Icon(Icons.assignment_turned_in_outlined, size: 20),
        label: const Text('Mark as returned'),
      );
      if (!desktop) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            markReturned,
            const SizedBox(height: 10),
            const Text(
              'These assets are out on loan. Marking them returned frees them '
              'and closes this loan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        );
      }
      return _desktopActionsBar([markReturned]);
    }
    if (request.status == RequestStatus.returned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.slateTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: const Row(
          children: [
            Icon(Icons.assignment_turned_in_outlined, color: AppTheme.muted, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'The borrowed assets have been returned and are available again. '
                'This loan is closed.',
                style: TextStyle(color: AppTheme.darkGreen, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    if (request.status == RequestStatus.rejected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.redTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.highlight_off, color: Color(0xFFC84040), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This request was rejected.',
                    style: TextStyle(
                      color: Color(0xFFC84040),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (request.rejectionReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      request.rejectionReason!,
                      style: const TextStyle(color: Color(0xFFC84040), fontSize: 13, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'Undo the rejected routing step above to reopen it.',
                    style: TextStyle(color: Color(0xFFC84040), fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Card-style action bar for desktop: matches the info/signatures cards
  /// above it (white background, rounded border) and right-aligns its
  /// buttons, rather than letting them float as bare, full-bleed widgets
  /// at the end of the page the way the mobile layout does.
  Widget _desktopActionsBar(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: children),
    );
  }
}

/// Status pill matching the one used on [RequestsScreen]'s cards.
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
        background = AppTheme.slateTint;
        foreground = AppTheme.muted;
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