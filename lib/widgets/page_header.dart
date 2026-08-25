import 'package:flutter/material.dart';

import 'brand_mark.dart';
import '../theme/app_theme.dart';

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMark) ...[
          const BrandMark(size: 84),
          const SizedBox(width: 28),
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
                        fontSize: 30,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 18,
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
