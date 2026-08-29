import 'package:flutter/material.dart';

import '../models/asset_request.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/signature_line.dart';

/// Full detail view for a single asset request. Shows every field the
/// requester entered, plus the approve/reject/cancel actions that used to
/// live only on the request card, so admins can act after reviewing the
/// full request instead of only from the list.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.request,
    this.onApprove,
    this.onReject,
    this.onCancel,
  });

  final AssetRequest request;

  /// Invoked when the admin approves a pending request. When null, no
  /// approve action is shown (mirrors [onReject]/[onCancel]).
  final VoidCallback? onApprove;

  /// Invoked when the admin rejects a pending request.
  final VoidCallback? onReject;

  /// Invoked when the admin cancels a previously-approved request, moving
  /// it back to pending.
  final VoidCallback? onCancel;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  void _approve() {
    widget.onApprove?.call();
    setState(() {});
  }

  void _reject() {
    widget.onReject?.call();
    setState(() {});
  }

  void _cancel() {
    widget.onCancel?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(
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
            const SizedBox(height: 24),
            _infoCard(request),
            const SizedBox(height: 24),
            _signaturesCard(request),
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
                const SizedBox(height: 30),
                _infoCard(request, desktop: true),
                const SizedBox(height: 24),
                _signaturesCard(request, desktop: true),
                const SizedBox(height: 24),
                _actions(request),
              ],
            ),
          ),
        ),
      );

  Widget _requestHeading(AssetRequest request, {bool desktop = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              request.title,
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontSize: desktop ? 32 : 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _RequestStatusPill(status: request.status),
        ],
      );

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
                Expanded(child: _detailRow('Needed by', request.neededDate)),
              ],
            ),
          ] else ...[
            _detailRow('Requested by', request.requester),
            _detailRow('Department / org', request.department),
            _detailRow('Venue / facility', request.venue ?? 'Not requested'),
            _detailRow('Needed by', request.neededDate),
          ],
          if (request.logistics.isNotEmpty) _itemsRow('Logistics', request.logistics),
          if (request.equipment.isNotEmpty) _itemsRow('Equipment', request.equipment),
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
                    child: Text(
                      item.name,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 16),
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

  /// The four "signature over printed name" blocks from the paper slip —
  /// requester, adviser, principal/office head, and dean — laid out side
  /// by side on desktop and two-per-row on mobile so they still resemble
  /// a signature strip rather than a stacked list.
  Widget _signaturesCard(AssetRequest request, {bool desktop = false}) {
    final signatories = request.signatories;
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Signatures',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                '${request.signedCount}/${signatories.length} signed',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in signatories)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SignatureLine(role: entry.key, signatory: entry.value),
                        ),
                      ),
                  ],
                )
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    for (final entry in signatories)
                      SignatureLine(role: entry.key, signatory: entry.value),
                  ],
                ),
        ],
      ),
    );
  }

  /// Approve/reject (pending) or cancel (approved) actions, matching what
  /// used to be available only from the request card on the list page.
  Widget _actions(AssetRequest request) {
    if (request.status == RequestStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onApprove == null ? null : _approve,
              child: const Text('Approve'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onReject == null ? null : _reject,
              child: const Text('Reject'),
            ),
          ),
        ],
      );
    }
    if (request.status == RequestStatus.approved) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: widget.onCancel == null ? null : _cancel,
          child: const Text('Cancel approval'),
        ),
      );
    }
    return const SizedBox.shrink();
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