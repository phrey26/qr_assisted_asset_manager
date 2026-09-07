import 'package:flutter/material.dart';

import '../models/removed_asset.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/page_header.dart';

/// Read-only log of every asset that was permanently deleted from the Stock
/// Items screen, with the reason the admin gave. Backed by the
/// `asset_removals` table (which has no foreign key to `assets`, so these
/// rows survive the asset being gone).
class RemovedAssetsScreen extends StatefulWidget {
  const RemovedAssetsScreen({super.key});

  @override
  State<RemovedAssetsScreen> createState() => _RemovedAssetsScreenState();
}

class _RemovedAssetsScreenState extends State<RemovedAssetsScreen> {
  final _searchController = TextEditingController();
  List<RemovedAsset>? _entries;
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
      final rows = await ApiService.fetchAssetRemovals();
      if (!mounted) return;
      setState(() {
        _entries = rows.map(RemovedAsset.fromJson).toList();
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

  List<RemovedAsset> get _visible {
    final all = _entries ?? const <RemovedAsset>[];
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Removed assets'),
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
                      title: 'Removed assets',
                      subtitle: total == 0
                          ? 'Permanently deleted assets appear here'
                          : '$total permanently deleted',
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
              'Could not load the removal log.',
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
            'Nothing here.\nAssets you delete from Stock Items are logged here with their reason.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 15, height: 1.5),
          ),
        ),
      );
    }

    return Column(
      children: [for (final entry in entries) _RemovedTile(entry: entry)],
    );
  }
}

class _RemovedTile extends StatelessWidget {
  const _RemovedTile({required this.entry});

  final RemovedAsset entry;

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
                decoration: const BoxDecoration(color: AppTheme.redTint, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Color(0xFFC84040), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
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
              Text(
                entry.formattedDate,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
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
                  'Reason for removal',
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
