import 'package:flutter/material.dart';

import '../models/bulk_disposal.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/page_header.dart';

/// Read-only log of every bulk-stock disposal — units written off (broken,
/// used up, lost, obsolete, or returned damaged) with the reason. Backed by
/// the `bulk_disposals` table, which has no foreign key to `assets` so the
/// records outlive the item.
class BulkDisposalsScreen extends StatefulWidget {
  const BulkDisposalsScreen({super.key});

  @override
  State<BulkDisposalsScreen> createState() => _BulkDisposalsScreenState();
}

class _BulkDisposalsScreenState extends State<BulkDisposalsScreen> {
  final _searchController = TextEditingController();
  List<BulkDisposal>? _entries;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ApiService.fetchBulkDisposals();
      if (!mounted) return;
      setState(() {
        _entries = rows.map(BulkDisposal.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<BulkDisposal> get _visible {
    final all = _entries ?? const <BulkDisposal>[];
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all
        .where((e) =>
            e.name.toLowerCase().contains(query) ||
            e.tagId.toLowerCase().contains(query) ||
            e.reason.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 900.0 : double.infinity;
    final total = _entries?.length ?? 0;
    final totalUnits =
        (_entries ?? const <BulkDisposal>[]).fold<int>(0, (sum, e) => sum + e.quantity);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Stock disposals'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: PageHeader(
                      title: 'Stock disposals',
                      subtitle: total == 0
                          ? 'Disposed bulk stock is logged here'
                          : '$total ${total == 1 ? 'entry' : 'entries'} · $totalUnits units written off',
                      showMark: false,
                    ),
                  ),
                ),
              ),
            ),
            if (!_loading && _error == null && total > 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 4),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 360 : maxWidth),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name, tag ID or reason',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(28, 12, 28, Responsive.bottomScrollClearance(context)),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _body(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text(
              'Could not load the disposal log.',
              style: TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final entries = _visible;
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Nothing here.\nUnits you dispose of from a bulk item are logged here with their reason.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 15, height: 1.5),
          ),
        ),
      );
    }

    return Column(
      children: [for (final entry in entries) _DisposalTile(entry: entry)],
    );
  }
}

class _DisposalTile extends StatelessWidget {
  const _DisposalTile({required this.entry});

  final BulkDisposal entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.redTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFC84040), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.name}  ·  −${entry.quantity}',
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.tagId}${entry.category == null ? '' : ' · ${entry.category}'}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.formattedDate,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  if (entry.disposedByName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'by ${entry.disposedByName}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F5F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.reason,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
