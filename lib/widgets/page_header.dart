import 'package:flutter/material.dart';

import 'brand_mark.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showMark = true,
  });

  final String title;
  final String? subtitle;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    // Scale the mark and type down on phones. At the fixed 84px/30px/18px
    // desktop sizes this header was crowding (and on very narrow phones,
    // wrapping oddly against) the rest of the app bar row on mobile.
    final scale = Responsive.fontScale(context);
    final markSize = showMark ? (Responsive.isMobile(context) ? 56.0 : 84.0) : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMark) ...[
          BrandMark(size: markSize),
          SizedBox(width: Responsive.isMobile(context) ? 18 : 28),
        ],
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: showMark ? 10 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 30 * scale,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 18 * scale,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}