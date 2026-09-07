import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/asset_return.dart';
import '../theme/app_theme.dart';
import 'image_viewer_screen.dart';

/// Renders an asset's condition & usage: a stat strip (times borrowed,
/// total days used, current condition), a wear note for IT equipment past
/// its lifespan, and the list of return inspections with their photos.
class AssetUsageView extends StatelessWidget {
  const AssetUsageView({super.key, required this.history, required this.asset});

  final AssetReturnHistory history;
  final AssetItem asset;

  @override
  Widget build(BuildContext context) {
    final summary = history.summary;
    final inspections = history.inspections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _stat('Times borrowed', '${summary.timesBorrowed}'),
            const SizedBox(width: 10),
            _stat('Days used', '${summary.daysUsed}'),
            const SizedBox(width: 10),
            _conditionStat(summary.currentCondition),
          ],
        ),
        if (asset.isPastLifespan) ...[
          const SizedBox(height: 14),
          _wearNote(
            'Past its ${AssetItem.itEquipmentLifespanYears}-year expected lifespan — '
            'weigh the wear below when deciding whether to keep it in service.',
          ),
        ],
        if (summary.currentCondition == AssetCondition.poor ||
            summary.currentCondition == AssetCondition.damaged) ...[
          const SizedBox(height: 14),
          _wearNote(
            'Last returned in ${summary.currentCondition!.label.toLowerCase()} condition — '
            'inspect before lending again.',
          ),
        ],
        const SizedBox(height: 18),
        if (inspections.isEmpty)
          const Text(
            'No return inspections yet. When a loan of this asset is marked returned, '
            'the condition and photos taken then show up here.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
          )
        else
          for (var i = 0; i < inspections.length; i++) ...[
            if (i > 0) const Divider(height: 28, color: AppTheme.border),
            _InspectionTile(inspection: inspections[i]),
          ],
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F5F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      );

  Widget _conditionStat(AssetCondition? condition) {
    final (bg, fg) = condition?.colors ?? (const Color(0xFFF6F5F0), AppTheme.muted);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(
              condition?.label ?? '—',
              style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text(
              'Condition',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wearNote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.redTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3C6C4), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFC84040), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFFC84040), fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.inspection});

  final AssetInspection inspection;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = inspection.condition.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
              child: Text(
                inspection.condition.label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
            const Spacer(),
            Text(
              AssetItem.formatDate(inspection.timestamp),
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (inspection.requestTitle != null)
          Text(
            'Loan: ${inspection.requestTitle}',
            style: const TextStyle(color: AppTheme.darkGreen, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        if (inspection.daysUsed != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Out for ${inspection.daysUsed} day${inspection.daysUsed == 1 ? '' : 's'}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
            ),
          ),
        if (inspection.notes != null) ...[
          const SizedBox(height: 6),
          Text(
            inspection.notes!,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
          ),
        ],
        if (inspection.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in inspection.photos)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ImageViewerScreen.open(
                    context,
                    imageBytes: photo,
                    title: 'Return photo',
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(photo, width: 84, height: 84, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
