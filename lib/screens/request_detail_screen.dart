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
                _actions(request, desktop: true),
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
              // A GridView.count with a fixed childAspectRatio forces every
              // cell to a rigid height derived from its width. That works
              // on a "typical" phone width, but on a narrower device the
              // cell shrinks below what the name + role text inside
              // SignatureLine actually needs, which is what was causing
              // the "BOTTOM OVERFLOWED" errors. A Wrap has no such
              // constraint — each item is only as tall as its own content,
              // so it can never overflow, on any screen width.
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final itemWidth = (constraints.maxWidth - spacing) / 2;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: 22,
                      children: [
                        for (final entry in signatories)
                          SizedBox(
                            width: itemWidth,
                            child: SignatureLine(role: entry.key, signatory: entry.value),
                          ),
                      ],
                    );
                  },
                ),
        ],
      ),
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
      final approve = ElevatedButton(
        onPressed: widget.onApprove == null ? null : _approve,
        style: desktop
            ? ElevatedButton.styleFrom(
                minimumSize: _desktopMinSize,
                padding: _desktopButtonPadding,
              )
            : null,
        child: const Text('Approve'),
      );
      final reject = OutlinedButton(
        onPressed: widget.onReject == null ? null : _reject,
        style: _rejectStyle(desktop: desktop),
        child: const Text('Reject'),
      );
      if (!desktop) {
        return Row(
          children: [
            Expanded(child: approve),
            const SizedBox(width: 12),
            Expanded(child: reject),
          ],
        );
      }
      return _desktopActionsBar([reject, const SizedBox(width: 12), approve]);
    }
    if (request.status == RequestStatus.approved) {
      final cancel = FilledButton.icon(
        onPressed: widget.onCancel == null ? null : _cancel,
        style: _cancelStyle(desktop: desktop),
        icon: const Icon(Icons.undo, size: 18),
        label: const Text('Cancel approval'),
      );
      if (!desktop) {
        return SizedBox(width: double.infinity, child: cancel);
      }
      return _desktopActionsBar([cancel]);
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