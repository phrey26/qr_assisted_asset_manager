import 'package:flutter/material.dart';

import '../models/asset_event.dart';
import '../theme/app_theme.dart';

/// Vertical timeline of an asset's history — a tinted dot per event, joined
/// by a connecting line, with the event title, optional context line, and a
/// formatted timestamp. Expects [events] newest-first (the order
/// `asset_events.php` returns).
class AssetTimeline extends StatelessWidget {
  const AssetTimeline({super.key, required this.events});

  final List<AssetEvent> events;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// e.g. "Jun 12, 2024 · 2:14 PM". Kept local so the app doesn't pull in
  /// intl just for this one label.
  static String _formatTimestamp(DateTime dt) {
    final date = '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final meridiem = dt.hour < 12 ? 'AM' : 'PM';
    return '$date · $hour12:$minute $meridiem';
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text(
        'No history recorded yet.',
        style: TextStyle(color: AppTheme.muted, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            isLast: i == events.length - 1,
            timestampLabel: _formatTimestamp(events[i].timestamp),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.timestampLabel,
  });

  final AssetEvent event;
  final bool isLast;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final (tint, foreground) = event.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(event.icon, size: 18, color: foreground),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppTheme.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (event.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.detail!,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    timestampLabel,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
